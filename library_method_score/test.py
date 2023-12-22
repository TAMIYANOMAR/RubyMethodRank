import networkx as nx

gd = nx.DiGraph()

for node in ["A", "B", "C", "D", "E", "F", "G", "H"]:
  gd.add_node(node)

edges = [
  ("A", "H"), ("C", "A"), ("A", "B"),
  ("F", "B"), ("C", "H"), ("E", "C"),
  ("F", "C"), ("H", "C"), ("C", "D"),
  ("H", "D"), ("B", "E"), ("D", "E"),
  ("H", "E"), ("A", "F"), ("B", "F"),
  ("D", "F"), ("E", "F"), ("F", "G"),
  ("D", "G"),
]
gd.add_edges_from(edges)

gd_pagerank = nx.pagerank(gd)

for key, value in gd_pagerank.items():
  print(key, value)