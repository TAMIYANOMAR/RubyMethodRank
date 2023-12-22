require 'parser/current'
require 'csv'
require 'json'
module LibraryMethodMap
    class Creator
        
        GemPath = File.expand_path('../../../gem_packages', __FILE__)
        LibJsonPath = File.expand_path('../../../RubyLibrarySetResolver/library_json_folder',__FILE__)
        LibHavePath = File.expand_path('../../../RubyLibrarySetResolver/lib_have',__FILE__)
        ExportJsonPath = File.expand_path('../export.json',__FILE__)
        CompedModelPath = File.expand_path('../../comped_model',__FILE__)
        EdgePath = File.expand_path('../../edge/edges.json',__FILE__)
        DumpedCSVPath = File.expand_path('../../edge/dumped.csv',__FILE__)

        def initialize
            @lib_haves = {}
            library_names = getLibs()

            # library_names.each do |libname,versions|
            #     if dumped?(libname)
            #         next
            #     end
            #     pp libname
            #     @comped_model = {}
            #     versions.each do |version|
            #         pp version
            #         ver_model = getMethodNamespace(createLibModel("#{libname}-#{version}"))
            #         modelComp(ver_model)
            #         pp @comped_model.keys()
            #     end
            #     @models = linkAsgn(@comped_model)
            #     dumpCompedModel(libname,@models)
            # end
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
            json_file = File.read("#{CompedModelPath}/#{lib_name}.json")
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

        def isBuiltInFunction?(name)#ここからコーディング
            built_in_function_list = ["+","new","[]","[]=","[]s","add_final","add_heap","ALLOC","ALLOC_N","ALLOCA_N","arg_add",
            "arg_ambiguous","arg_blk_pass","arg_concat","arg_defined","arg_prepend","aryset",
            "assign","assign_in_cond","assignable","attrset","autoload_i","avalue_to_svalue",
            "avalue_to_yvalue","backtrace","bind_clone","blk_copy_prev","blk_free","blk_mark",
            "blk_orphan","block_append","block_pass","bm_mark","bmcall","boot_defclass",
            "BUILTIN_TYPE","call_cfunc","call_end_proc","call_final","call_op","call_trace_func",
            "catch_i","catch_timer","Check_Type","CHR2FIX","CLASS_OF","classname",
            "clone_method","CLONESETUP","compile","compile_error","cond","cond0",
            "convert_type","copy_fds","copy_node_scope","cv_i","cvar_cbase","cvar_override_check",
            "Data_Get_Struct","Data_Make_Struct","DATA_PTR","Data_Wrap_Struct","define_final","delete_never",
            "DUPSETUP","dvar_asgn","dvar_asgn_curr","dvar_asgn_internal","dyna_in_block","dyna_pop",
            "dyna_push","e_option_supplied","errat_getter","errat_setter","errinfo_setter","error_handle",
            "error_pos","error_print","ev_const_defined","ev_const_get","eval","eval_node",
            "eval_under","eval_under_i","exec_under","fc_i","fc_path","finals",
            "find_bad_fds","find_class_path","FIX2INT","FIX2LONG","FIX2UINT","FIX2ULONG",
            "FIXABLE","FIXNUM_MAX","FIXNUM_MIN","FIXNUM_P","fixpos","FL_ABLE",
            "FL_REVERSE","FL_SET","FL_TEST","FL_UNSET","frame_dup","gc_mark_all",
            "gc_mark_rest","gc_sweep","generic_ivar_defined","generic_ivar_get","generic_ivar_remove","generic_ivar_set",
            "get_backtrace","gettable","givar_i","givar_mark_i","global_id","gvar_i",
            "handle_rescue","here_document","heredoc_identifier","heredoc_restore","id2ref","ID2SYM",
            "IMMEDIATE_P","include_class_new","Init_eval","Init_heap","Init_load","init_mark_stack",
            "Init_Proc","Init_stack","Init_sym","Init_Thread","Init_var_tables","ins_methods_i",
            "ins_methods_priv_i","ins_methods_prot_i","inspect_i","inspect_obj","INT2FIX","INT2NUM",
            "internal_id","intersect_fds","is_defined","is_pointer_to_heap","ISALNUM","ISALPHA",
            "ISASCII","ISDIGIT","ISLOWER","ISPRINT","ISSPACE","ISUPPER",
            "ISXDIGIT","ivar_i","jump_tag_but_local_jump","lex_get_str","lex_getline","list_append",
            "list_concat","list_i","literal_append","literal_concat","literal_concat_dstr","literal_concat_list",
            "literal_concat_string","LL2NUM","local_append","local_cnt","local_id","local_pop",
            "local_push","local_tbl","localjump_error","localjump_exitstatus","logop","LONG2FIX",
            "LONG2NUM","make_backtrace","mark_entry","mark_global_entry","mark_hashentry","mark_locations_array",
            "mark_source_filename","massign","match_fds","match_gen","MEMCMP","MEMCPY",
            "MEMMOVE","MEMZERO","method_arity","method_call","method_clone","method_eq",
            "method_inspect","method_list","method_proc","method_unbind","mnew","mod_av_set",
            "module_setup","mproc","mvalue_to_svalue","NEGFIXABLE","new_blktag","new_call",
            "new_dvar","new_fcall","new_size","new_super","newline_node","NEWOBJ",
            "newtok","nextc","NIL_P","node_assign","nodeline","nodetype",
            "NUM2CHR","NUM2DBL","NUM2INT","NUM2LONG","NUM2SHORT","NUM2UINT",
            "NUM2ULONG","NUM2USHORT","numcmp","numhash","obj_free","OBJ_FREEZE",
            "OBJ_FROZEN","OBJ_INFECT","OBJ_TAINT","OBJ_TAINTED","OBJSETUP","original_module",
            "os_each_obj","os_live_obj","os_obj_of","parse_string","peek","pipe_open",
            "POSFIXABLE","print_undef","proc_arity","proc_binding","proc_call","proc_eq",
            "proc_get_safe_level","proc_invoke","proc_new","proc_s_new","proc_save_safe_level","proc_set_safe_level",
            "proc_to_proc","proc_to_s","proc_yield","pushback","range_op","RARRAY",
            "rb_add_method","rb_alias","rb_alias_variable","rb_any_to_s","rb_apply","rb_Array",
            "rb_ary_aref","rb_ary_clear","rb_ary_concat","rb_ary_delete","rb_ary_entry","rb_ary_includes",
            "rb_ary_new","rb_ary_new2","rb_ary_new3","rb_ary_pop","rb_ary_push","rb_ary_shift",
            "rb_ary_sort","rb_ary_store","rb_ary_to_s","rb_ary_unshift","rb_assoc_new","rb_attr",
            "rb_autoload","rb_autoload_defined","rb_autoload_id","rb_autoload_load","rb_backref_error","rb_backref_get",
            "rb_backref_set","rb_backtrace","rb_block_given_p","rb_call","rb_call0","rb_call_super",
            "rb_callcc","rb_catch","rb_check_convert_type","rb_class2name","rb_class_allocate_instance","rb_class_boot",
            "rb_class_inherited","rb_class_initialize","rb_class_instance_methods","rb_class_new","rb_class_new_instance","rb_class_path",
            "rb_class_private_instance_methods","rb_class_protected_instance_methods","rb_class_real","rb_class_s_new","rb_class_superclass","rb_clear_cache",
            "rb_clear_cache_by_class","rb_clear_cache_by_id","rb_compile_cstr","rb_compile_error","rb_compile_error_with_enc","rb_compile_file",
            "rb_compile_string","rb_const_assign","rb_const_defined","rb_const_defined_at","rb_const_get","rb_const_get_at",
            "rb_const_list","rb_const_set","rb_cont_call","rb_convert_type","rb_copy_generic_ivar","rb_cstr_to_dbl",
            "rb_cv_get","rb_cv_set","rb_cvar_declear","rb_cvar_defined","rb_cvar_get","rb_cvar_set",
            "rb_data_object_alloc","rb_define_alias","rb_define_attr","rb_define_class","rb_define_class_id","rb_define_class_under",
            "rb_define_class_variable","rb_define_const","rb_define_global_const","rb_define_global_function","rb_define_hooked_variable","rb_define_method",
            "rb_define_method_id","rb_define_module","rb_define_module_function","rb_define_module_id","rb_define_module_under","rb_define_private_method",
            "rb_define_protected_method","rb_define_readonly_variable","rb_define_singleton_method","rb_define_variable","rb_define_virtual_variable","rb_disable_super",
            "rb_dvar_curr","rb_dvar_defined","rb_dvar_push","rb_dvar_ref","rb_enable_super","rb_ensure",
            "rb_eql","rb_equal","rb_eval","rb_eval_cmd","rb_eval_string","rb_eval_string_protect",
            "rb_eval_string_wrap","rb_exc_fatal","rb_exc_raise","rb_exec_end_proc","rb_exit","rb_export_method",
            "rb_extend_object","rb_f_abort","rb_f_array","rb_f_at_exit","rb_f_autoload","rb_f_binding",
            "rb_f_block_given_p","rb_f_caller","rb_f_catch","rb_f_END","rb_f_eval","rb_f_exit",
            "rb_f_float","rb_f_global_variables","rb_f_hash","rb_f_integer","rb_f_lambda","rb_f_load",
            "rb_f_local_variables","rb_f_loop","rb_f_missing","rb_f_raise","rb_f_require","rb_f_send",
            "rb_f_string","rb_f_throw","rb_f_trace_var","rb_f_untrace_var","rb_false","rb_fatal",
            "rb_feature_p","rb_fix_new","rb_Float","rb_frame_last_func","rb_free_generic_ivar","rb_frozen_class_p",
            "rb_funcall","rb_funcall2","rb_funcall3","rb_gc","rb_gc_call_finalizer_at_exit","rb_gc_disable",
            "rb_gc_enable","rb_gc_force_recycle","rb_gc_mark","rb_gc_mark_children","rb_gc_mark_frame","rb_gc_mark_global_tbl",
            "rb_gc_mark_locations","rb_gc_mark_maybe","rb_gc_mark_threads","rb_gc_register_address","rb_gc_start","rb_gc_unregister_address",
            "rb_generic_ivar_table","rb_get_method_body","rb_global_entry","rb_global_variable","rb_gv_get","rb_gv_set",
            "rb_gvar_defined","rb_gvar_get","rb_gvar_set","rb_id2name","rb_id_attrset","rb_include_module",
            "rb_inspect","rb_int_new","rb_Integer","rb_intern","rb_interrupt","rb_io_mode_flags2",
            "rb_is_class_id","rb_is_const_id","rb_is_instance_id","rb_is_local_id","rb_iter_break","rb_iterate",
            "rb_iterator_p","rb_iv_get","rb_iv_set","rb_ivar_defined","rb_ivar_get","rb_ivar_set",
            "rb_jump_tag","rb_lastline_get","rb_lastline_set","rb_load","rb_load_protect","rb_longjmp",
            "rb_make_metaclass","rb_mark_end_proc","rb_mark_generic_ivar","rb_mark_generic_ivar_tbl","rb_mark_hash","rb_mark_tbl",
            "rb_memerror","rb_method_boundp","rb_mod_alias_method","rb_mod_ancestors","rb_mod_append_features","rb_mod_attr",
            "rb_mod_attr_accessor","rb_mod_attr_reader","rb_mod_attr_writer","rb_mod_class_variables","rb_mod_clone","rb_mod_cmp",
            "rb_mod_const_at","rb_mod_const_defined","rb_mod_const_get","rb_mod_const_of","rb_mod_const_set","rb_mod_constants",
            "rb_mod_define_method","rb_mod_dup","rb_mod_eqq","rb_mod_extend_object","rb_mod_ge","rb_mod_gt",
            "rb_mod_include","!","!=","==","__id__","__send__","equal?","instance_eval","instance_exec","new","argv",
            "binmode","binmode?","close","closed?","each","each_byte","each_char","each_codepoint","each_line","eof",
            "eof?","external_encoding","file","filename","fileno","getbyte","getc","gets","inplace_mode","inplace_mode=",
            "inspect","internal_encoding","lineno","lineno=","path","pos","pos=","print","printf","putc",
            "puts","read","read_nonblock","readbyte","readchar","readline","readlines","readpartial","rewind","seek",
            "set_encoding","skip","tell","to_a","to_i","to_io","to_s","to_write_io","write","[]",
            "new","try_convert","eval","irb","local_variable_defined?","local_variable_get","local_variable_set","local_variables","receiver","source_location",
            "[]","define","members","new","[]","chdir","children","chroot","delete","each_child",
            "empty?","entries","exist?","foreach","getwd","glob","home","mkdir","new","open",
            "pwd","rmdir","unlink","aliases","compatible?","default_external","default_external=","default_internal","default_internal=","find",
            "list","locale_charmap","name_list","new","produce","&","^","|","inspect","to_s",
            "current","new","yield","[]","new","ruby2_keywords_hash?","try_convert","absolute_path","absolute_path?","atime",
            "basename","birthtime","blockdev?","chardev?","chmod","chown","ctime","delete","directory?","dirname",
            "empty?","executable?","executable_real?","exist?","expand_path","extname","file?","fnmatch","fnmatch?","ftype",
            "grpowned?","identical?","join","lchmod","lchown","link","lstat","lutime","mkfifo","mtime",
            "new","open","owned?","path","pipe?","readable?","readable_real?","readlink","realdirpath","realpath",
            "rename","setgid?","setuid?","size","size?","socket?","split","stat","sticky?","symlink",
            "symlink?","truncate","umask","unlink","utime","world_readable?","world_writable?","writable?","writable_real?","zero?",
            "==","[]","begin","byteoffset","captures","end","eql?","hash","inspect","length",
            "named_captures","names","offset","post_match","pre_match","regexp","size","string","to_a","to_s",
            "values_at","<<","==","===",">>","[]","arity","call","clone","curry",
            "eql?","hash","inspect","name","original_name","owner","parameters","receiver","source_location","super_method",
            "to_proc","to_s","unbind","constants","nesting","new","used_modules","new","import_methods","&",
            "=~","^","|","nil?","rationalize","to_a","to_c","to_f","to_h","to_i",
            "to_r","to_s","%","+@","-@","<=>","abs","abs2","angle","arg",
            "ceil","coerce","conj","conjugate","denominator","div","divmod","eql?","fdiv","finite?",
            "floor","i","imag","imaginary","infinite?","integer?","magnitude","modulo","negative?","nonzero?",
            "numerator","phase","polar","positive?","quo","real","real?","rect","rectangular","remainder",
            "round","step","to_c","to_int","truncate","zero?","polar","rect","rectangular","%",
            "*","**","+","-","-@","/","<","<=","<=>","==",">",">=","abs","angle","arg","ceil",
            "denominator","divmod","eql?","finite?","floor","hash","infinite?","inspect",
            "magnitude","modulo","nan?","negative?","next_float","numerator","phase","positive?",
            "prev_float","rationalize","round","to_f","to_i","to_r","to_s","truncate","zero?",
            "sqrt","try_convert","*","**","+","-","-@","/","<=>","==","abs","ceil","coerce","denominator",
            "fdiv","floor","hash","inspect","magnitude","negative?","numerator","positive?","quo",
            "rationalize","round","to_f","to_i","to_r","to_s","truncate","new","bytes","new","new_seed",
            "rand","srand","urandom","new","compile","escape","last_match","new","quote","try_convert",
            "union","DEFAULT_PARAMS","INSTRUCTION_NAMES","OPTS","new","try_convert","[]","keyword_init?",
            "members","new","all_symbols","at","gm","local","mktime","new","now","utc","new","stat","trace",
            "&","^","|","inspect","to_s"]
      
            return built_in_function_list.include?(name)
          end

    end
end

method_map_creator = LibraryMethodMap::Creator.new()
