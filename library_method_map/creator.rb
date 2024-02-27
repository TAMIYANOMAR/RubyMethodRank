require 'parser/current'
require 'csv'
require 'json'
module LibraryMethodMap
    class Creator
        PluginPath = File.expand_path('../../../redmine_plugins', __FILE__)
        PlguinDependencyPath = File.expand_path('../../../RedminePluginCompatibilityResolver/plugin_json_folder', __FILE__)
        GemPath = File.expand_path('../../../gem_packages', __FILE__)
        LibJsonPath = File.expand_path('../../../RubyLibrarySetResolver/library_json_folder',__FILE__)
        LibHavePath = File.expand_path('../../../RubyLibrarySetResolver/lib_have',__FILE__)
        ExportJsonPath = File.expand_path('../export.json',__FILE__)
        CompedModelPath = File.expand_path('../../comped_model',__FILE__)
        EdgePath = File.expand_path('../../edge/edges.json',__FILE__)
        DumpedCSVPath = File.expand_path('../../edge/dumped.csv',__FILE__)

        def initialize(create_node = false,plugin = true)
            if plugin
                plugin_names = getPlugins(PluginPath)
                if create_node
                    depend_libs = []
                    plugin_names.each do |plugin_name,versions|
                        pp plugin_name
                        depend_libs = getPluginDependLibs(plugin_name)
                        if depend_libs == nil or depend_libs == []
                            next
                        end
                        @comped_model = {}
                        versions.each do |version|
                            ver_model = getMethodNamespace(getPluginModel(plugin_name,version))
                            modelComp(ver_model)
                        end
                        linkAsgn(@comped_model)
                        dumpCompedModel("#"+plugin_name,@comped_model)
                    end
                else
                    plugin_names.each do |plugin_name,versions|
                        pp plugin_name
                        if edgeDumped?("#"+plugin_name)
                            next
                        end
                        edges = []
                        depend_libs = getPluginDependLibs(plugin_name)
                        if depend_libs == nil or depend_libs == []
                            next
                        end
                        plugin_model = loadCompedModel("#"+plugin_name)
                        if depend_libs == nil
                            next
                        end
                        depend_libs.each do |depend_lib|
                            pp "depend_lib:#{depend_lib}"
                            depend_model = loadCompedModel(depend_lib)
                            if depend_model == nil
                                next
                            end
                            edges += getMethodEdge(plugin_model,depend_model,"#"+plugin_name,depend_lib)
                        end
                        dumpEdges(edges,"#"+plugin_name)
                        file = File.open(DumpedCSVPath,'a')
                        file.puts("#"+plugin_name)
                    end
                end
            else
                library_names = getLibs()
                if create_node
                    library_names.each do |libname,versions|
                        if dumped?(libname)
                            next
                        end
                        pp libname
                        @comped_model = {}
                        versions.each do |version|
                            pp version
                            ver_model = getMethodNamespace(createLibModel("#{libname}-#{version}"))
                            modelComp(ver_model)
                            pp @comped_model.keys()
                        end
                        linkAsgn(@comped_model)
                        dumpCompedModel(libname,@comped_model)
                    end  
                else
                    library_names.each do |libname,versions|
                        pp "libname:#{libname}"
                        if edgeDumped?(libname)
                            next
                        end
                        edges = []
                        lib_model = loadCompedModel(libname)
                        depend_libs = getDependLibs(libname)
                        
                        if depend_libs == nil
                            next
                        end
                        depend_libs.each do |depend_lib|
                            pp "depend_lib:#{depend_lib}"
                            depend_model = loadCompedModel(depend_lib)
                            edges += getMethodEdge(lib_model,depend_model,libname,depend_lib)
                        end
                        dumpEdges(edges,libname)
                        file = File.open(DumpedCSVPath,'a')
                        file.puts(libname)
                    end
                end
            end
        end

        def edgeDumped?(libname)
            CSV.foreach(DumpedCSVPath) do |row|
                if row[0] == libname
                    return true
                end
            end
            return false
        end

        def dumpCompedModel(lib_name,comped_model)
            JSON.dump(comped_model,File.open("#{CompedModelPath}/#{lib_name}.json",'w'))
        end

        def loadCompedModels()
            comped_models = {}
            Dir.glob("#{CompedModelPath}/*.json").each do |file|
                lib_name = File.basename(file).delete_suffix('.json')
                comped_models[lib_name] = JSON.parse(File.read(file))
            end
            return comped_models
        end

        def loadCompedModel(lib_name)
            begin
                json_file = File.read("#{CompedModelPath}/#{lib_name}.json")
            rescue
                return nil
            end
            comped_model = JSON.parse(json_file)
            return comped_model
        end

        def dumpEdges(edges,lib_name)
            edges.each do |edge|
                File.open(EdgePath,'a') do |f|
                    JSON.dump(edge,f)
                    f.puts(',')
                end
            end
        end

        def dumped?(libname)
            if File.exist?("#{CompedModelPath}/#{libname}.json")
                return true
            else
                return false
            end
        end

        def getPlugins(plugin_path)
            plugins = {}
            Dir.glob("#{plugin_path}/*").each do |plugin|
                plugin_name = File.basename(plugin)
                versions = []
                Dir.glob("#{plugin_path}/#{plugin_name}/*").each do |version|
                    versions << File.basename(version)
                end
                plugins[plugin_name] = versions
            end
            return plugins
        end
        def getPluginModel(plugin_name,version)
            plugin_model = {'plugin_name' => plugin_name, 'version' => version, 'model' => []}
            plugin_asts = []
            Dir.glob("#{PluginPath}/#{plugin_name}/#{version}/lib/**/*.rb").each do |file|
                begin
                    plugin_asts << Parser::CurrentRuby.parse(File.read(file))
                rescue
                    next
                end
            end
            plugin_asts.each do |ast|
                getModel(ast,plugin_model['model'])
            end
            return plugin_model
        end
        def getPluginDependLibs(plugin_name)
            depend_libs = []
            begin
                json_file = File.read("#{PlguinDependencyPath}/#{plugin_name}.json")
            rescue
                return []
            end
            json = JSON.parse(json_file)
            json['versions'].each do |vers_and_deps|
                vers_and_deps['dependencies'].each do |dependency|
                    depend_libs << dependency['name']
                end
            end
            return depend_libs.uniq!
        end

        def getMethodEdge(lib,lib_depend,libname,lib_depend_name)
            edges = []
            lib.each do |fullname,method_namespace|
                lib_depend.each do |depend_fullname,method_depend_namespace|
                    method_namespace['call'].each do |call|
                        if callMatch(call,depend_fullname)
                            edges << { 'from_lib' => libname, 'from_method' => fullname, 'to_lib' => lib_depend_name, 'to_method' => depend_fullname}
                        end
                    end
                end
            end
            return edges.uniq
        end

        def callMatch(call,namespace)
            while call.include?('  ') or namespace.include?('  ')
                call = call.gsub('  ',' ')
                namespace = namespace.gsub('  ',' ')
            end
            call = call.gsub('new','initialize')
            call_elements = call.split(' ')
            namespace_elements = namespace.split(' ')
            namespace_elements.each do |namespace_element|
                if call_elements.include?(namespace_element) == false
                    return false
                end
            end
            return true
        end


        def getDependLibs(libname)
            depend_libs = []
            json_file = File.read("#{LibJsonPath}/#{libname}.json")
            json = JSON.parse(json_file)
            json['vers_and_deps'].each do |ver_and_dep|
                ver_and_dep['dependencies'].each do |dependency|
                    depend_libs << dependency['name']
                end
            end
            return depend_libs.uniq!
        end

        def getMethodNamespace(ver_model)
            method_namespace = []
            stack = []
            ver_model['model'].each do |model|
                #dump model
                # JSON.dump(model,File.open(ExportJsonPath,'w'))
                stack << {'namespace' => '', 'model' => model}
            end

            while stack.empty? == false
                curr_model = stack.pop
                if curr_model['model']['type'] == 'method'
                    method_namespace << {'namespace' => curr_model['namespace'], 'model' => curr_model['model']}
                elsif curr_model['model']['type'] == 'module' or curr_model['model']['type'] == 'class'
                    curr_model['model']['children'].each do |child|
                        stack << {'namespace' => curr_model['namespace'] + ' ' + curr_model['model']['name'] , 'model' => child}
                    end
                end

            end
            return method_namespace
        end

        def modelComp(ver_method_namespace)
            comped_model = {} 
            ver_method_namespace.each do |method_namespace|
                if method_namespace == nil
                    next
                end
                if method_namespace['model'] == nil
                    next
                end
                if @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']] == nil
                    @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']] = method_namespace['model']
                else
                    @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']]['call'] += method_namespace['model']['call']
                    @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']]['asgn'] += method_namespace['model']['asgn']
                    @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']]['asgn'].uniq!
                    @comped_model[method_namespace['namespace'] + ' ' + method_namespace['model']['name']]['call'].uniq!
                end
            end
        end


        def getLibs()
            library_names = {}
            Dir.glob("#{GemPath}/*").each do |lib|
                string = File.basename(lib)
                # if string.include?('icalendar') == false and string.include?('ice_cube') == false
                #     next
                # end
                lib_version = string.split('-')[string.split('-').length-1]
                lib_name = string.delete_suffix("-#{lib_version}")
                if library_names.key?(lib_name) == false
                    library_names[lib_name] = [lib_version]
                else
                    library_names[lib_name] << lib_version
                end
            end
            return library_names
        end

        def createLibModel(libname)
            lib_model = {'libname' => libname, 'model' => []}
            lib_asts = []
            Dir.glob("#{GemPath}/#{libname}/lib/**/*.rb").each do |file|
                begin
                    lib_asts << Parser::CurrentRuby.parse(File.read(file))
                rescue
                    next
                end
            end
            lib_asts.each do |ast|
                getModel(ast,lib_model['model'])
            end
            return lib_model
        end

        def getModel(node,model)
            current_model = { 'type' => '' ,'name' => '' ,'children' => [] ,'asgn' => [] ,'call' => []}
            if node.is_a?(Parser::AST::Node) == false
                return
            end
            if node.type == :module
                module_name = node.children[0].children[1].to_s
                current_model['type'] = 'module'
                current_model['name'] = module_name
            elsif node.type == :class
                class_name = node.children[0].children[1].to_s
                current_model['type'] = 'class'
                current_model['name'] = class_name
            elsif node.type == :def or node.type == :defs
                if node.type == :defs
                    method_name = node.children[1].to_s
                else
                    method_name = node.children[0].to_s
                end
                current_model['type'] = 'method'
                current_model['name'] = method_name
                stack = []
                stack << node.children[2]
                while stack.empty? == false
                    curr_node = stack.pop
                    if curr_node.is_a?(Parser::AST::Node) == false
                        next
                    end
                    if curr_node.type == :send
                        current_model['call'] << getSend(curr_node)
                    elsif curr_node.type == :ivasgn or curr_node.type == :lvasgn or curr_node.type == :cvasgn or curr_node.type == :gvasgn
                        current_model['asgn'] << getAsgn(curr_node,current_model['asgn'])
                    end
                    curr_node.children.each do |child|
                        stack << child
                    end
                end
            end
            if current_model['type'] != ''
                node.children.each do |child|
                    getModel(child,current_model['children'])
                end
                model << current_model
            else
                node.children.each do |child|
                    getModel(child,model)
                end
            end    
        end

        def getAsgn(node,asgn)
            var_name = ''
            type = ''
            values = []

            if node.is_a?(Parser::AST::Node) == false
                return
            end

            if node.type == :ivasgn
                var_name = node.children[0].to_s
                type = 'instance'
                values = getValues(node.children[1])
            elsif node.type == :lvasgn
                var_name = node.children[0].to_s
                type = 'local'
                values = getValues(node.children[1])
            elsif node.type == :cvasgn
                var_name = node.children[0].to_s
                type = 'class'
                values = getValues(node.children[1])
            elsif node.type == :gvasgn
                var_name = node.children[0].to_s
                type = 'global'
                values = getValues(node.children[1])
            end

            if values.empty? == false
                values.each do |value|
                    asgn << {'type' => type, 'name' => var_name, 'value' => value}
                end
            end
        end

        def getValues(node)
            values = []
            if node.is_a?(Parser::AST::Node) == false
                return []
            end
            if node.type == :send
                values = [getSend(node)]
            elsif node.type == :if
                values = getIf(node)
            end
            return values
        end

        def getSend(node)
            string = ''
            if node.children[0].is_a?(Parser::AST::Node)
                while node.children[0].type == :send
                    string = node.children[1].to_s + ' ' + string
                    node = node.children[0]
                    if node.children[0].is_a?(Parser::AST::Node) == false
                        break
                    end
                end
            end
            reciever = ''
            name = node.children[1].to_s
            if node.children[0].is_a?(Parser::AST::Node)
                if node.children[0].type == :const
                    reciever = getConst(node.children[0])
                else
                    reciever = node.children[0].children[0].to_s
                end
            end
            string = reciever + ' ' + name + ' ' + string
            return string
        end

        def getIf(node)
            values = []
            stack = []
            stack << node.children[1]
            stack << node.children[2]
            while stack.empty? == false
                curr_node = stack.pop
                if curr_node.is_a?(Parser::AST::Node) == false
                    next
                end
                if curr_node.type == :send
                    values << getSend(curr_node)
                end
            end
            return values
        end

        def getConst(node)
            stack = []
            stack << node
            string = ''
            while stack.empty? == false
                curr_node = stack.pop
                if curr_node.is_a?(Parser::AST::Node) == false
                    next
                end 
                string = curr_node.children[1].to_s + ' ' + string
                curr_node.children.each do |child|
                    stack << child
                end
            end
            return string
        end

        def linkAsgn(method_namespaces)
            method_namespaces.each do |namespace,method_namespace|
                linked_calls = []
                asgns = {}
                # pp method_namespace
                if method_namespace['asgn'] == nil or method_namespace['call'] == nil
                    next
                end
                method_namespace['asgn'].each do |asgn|
                    begin
                        if asgns[asgn['name']] == nil
                            asgns[asgn['name']] = []
                        end
                        asgns[asgn['name']] << asgn
                    rescue
                        next
                    end
                end
                method_namespace['call'].each do |call|
                    asgns.each do |asgn_name,asgn_values|
                        if call.include?(asgn_name)
                            asgn_values.each do |asgn_value|
                                linked_calls << call.gsub(asgn_name,asgn_value['value'])
                            end
                        end
                    end
                end
                method_namespace['call'] += linked_calls
                method_namespace['call'].uniq!
                method_namespace.delete('asgn')
            end
        end
    end
end

method_map_creator = LibraryMethodMap::Creator.new()
