import networkx as nx
import os
import json
import pprint
ModelDirPath = os.path.join(os.path.dirname(__file__), '../comped_model')
EdgePath = os.path.join(os.path.dirname(__file__), '../edge/edge.json')

def get_lib_name(model_dir_parh):
    json_names = os.listdir(model_dir_parh)
    lib_names = []
    for json_name in json_names:
        lib_names.append(json_name.split('.')[0])
    return lib_names

def add_node(di_graph, lib_names):
    for lib_name in lib_names:
        with open(os.path.join(ModelDirPath, lib_name + '.json'), 'r') as f:
            model = json.load(f)
        for method in model:
            di_graph.add_node(lib_name + method)
    return di_graph

def add_edge(di_graph, edge_json_path):
    edge_json = json.load(open(edge_json_path, 'r'))
    for edge in edge_json:
        di_graph.add_edge(edge['from_lib'] + edge['from_method'], edge['to_lib'] + edge['to_method'])
    return di_graph

def caluclate_score(di_graph):
    score = nx.pagerank(di_graph)
    return score

lib_names = get_lib_name(ModelDirPath)
di_graph = nx.DiGraph()
di_graph = add_node(di_graph, lib_names)
di_graph = add_edge(di_graph, EdgePath)

