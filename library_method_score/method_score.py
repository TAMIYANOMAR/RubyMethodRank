import networkx as nx
import os
import json
from insert_to_sql import SQLManiplator

class MethodScore:
    
    def __init__(self):
        self.new_di_graph = nx.DiGraph()
        di_graph = nx.DiGraph()
        ModelDirPath = os.path.join(os.path.dirname(__file__), '../comped_model')
        EdgePath = os.path.join(os.path.dirname(__file__), '../edge/edges.json')
        DumpPath = os.path.join(os.path.dirname(__file__), '../method_score')
        lib_names = self.get_lib_name(ModelDirPath)
        
        di_graph = self.add_node(di_graph, lib_names, ModelDirPath)
        di_graph = self.add_edge(di_graph, EdgePath)
        scores = self.caluclate_score(di_graph)
        sql_manipulator = SQLManiplator("localhost", "root", "root", "method_score_db")
        self.dump_score(scores, DumpPath, sql_manipulator)

    def get_lib_name(self, model_dir_parh):
        json_names = os.listdir(model_dir_parh)
        lib_names = []
        for json_name in json_names:
            lib_names.append(json_name.split('.')[0])
        return lib_names

    def add_node(self, di_graph, lib_names, model_dir_path):
        for lib_name in lib_names:
            with open(os.path.join(model_dir_path, lib_name + '.json'), 'r') as f:
                model = json.load(f)
            for method in model:
                di_graph.add_node(lib_name + method)
        return di_graph

    def add_edge(self, di_graph, edge_json_path):
        edge_json = json.load(open(edge_json_path, 'r'))
        for edge in edge_json:
            if (edge['from_lib'] + edge['from_method']) in di_graph.nodes and (edge['to_lib'] + edge['to_method']) in di_graph.nodes:
                self.new_di_graph.add_node(edge['from_lib'] + edge['from_method'])
                self.new_di_graph.add_node(edge['to_lib'] + edge['to_method'])
                self.new_di_graph.add_edge(edge['from_lib'] + edge['from_method'], edge['to_lib'] + edge['to_method'])
                # print("edge:"  + edge['from_lib'] + edge['from_method'], edge['to_lib'] + edge['to_method'])
                di_graph.add_edge(edge['from_lib'] + edge['from_method'], edge['to_lib'] + edge['to_method'])
        return di_graph

    def caluclate_score(self, di_graph):
        print("start calculate score")
        print("node num:{}".format(len(di_graph.nodes)))
        print("edge num:{}".format(len(di_graph.edges)))
        score = nx.pagerank(di_graph, max_iter=1000, tol=1e-09)
        # score = nx.pagerank(self.new_di_graph)
        return score
    
    def dump_score(self, score, dump_path, sql_manipulator):
        score_hash = dict()
        now_score = None
        for key, value in score.items():
            if now_score != value:
                now_score = value
                print("{}:{}".format(key, value))
            lib_name = key.split(' ')[0]
            method_name = key.strip(lib_name + ' ')
            if lib_name not in score_hash:
                score_hash[lib_name] = dict()
            score_hash[lib_name][method_name] = value
            sql_manipulator.insert_method_score(lib_name, method_name, str(value))
            # with open(os.path.join(dump_path,lib_name + '.json'), 'w') as f:
            #     json_file = json.dumps(score_hash[lib_name], indent=4)
            #     f.write(json_file)