// A* shortest path — finds optimal walking route through building graph

class PriorityQueue {
  constructor() { this.items = []; }
  enqueue(node, priority) {
    this.items.push({ node, priority });
    this.items.sort((a, b) => a.priority - b.priority);
  }
  dequeue() { return this.items.shift(); }
  isEmpty()  { return this.items.length === 0; }
}

// Straight-line distance estimate between two rooms
function heuristic(a, b, coords) {
  if (coords[a] && coords[b]) {
    const dx = coords[a].x - coords[b].x;
    const dy = coords[a].y - coords[b].y;
    return Math.sqrt(dx * dx + dy * dy);
  }
  return 0;
}

// Build adjacency map: { roomId: [ {to, cost, direction}, ... ] }
function buildGraph(edges) {
  const graph = {};
  for (const e of edges) {
    if (!graph[e.from_node]) graph[e.from_node] = [];
    graph[e.from_node].push({ to: e.to_node, cost: e.distance, direction: e.direction });
  }
  return graph;
}

function aStar(graph, start, goal, coords = {}) {
  if (!graph[start]) return { found:false, path:[], directions:[], totalCost:0 };
  if (start === goal) return { found:true,  path:[start], directions:[], totalCost:0 };

  const queue    = new PriorityQueue();
  const cameFrom = {};
  const gScore   = {};
  const dirMap   = {};

  for (const n of Object.keys(graph)) gScore[n] = Infinity;
  gScore[start] = 0;
  queue.enqueue(start, heuristic(start, goal, coords));

  while (!queue.isEmpty()) {
    const { node: cur } = queue.dequeue();
    if (cur === goal) {
      const path = [], dirs = [];
      let c = goal;
      while (c !== undefined) {
        path.unshift(c);
        if (dirMap[c]) dirs.unshift(dirMap[c]);
        c = cameFrom[c];
      }
      return { found:true, path, directions:dirs, totalCost:Math.round(gScore[goal]) };
    }
    for (const nb of (graph[cur] || [])) {
      const ng = gScore[cur] + nb.cost;
      if (ng < (gScore[nb.to] ?? Infinity)) {
        cameFrom[nb.to] = cur;
        dirMap[nb.to]   = nb.direction;
        gScore[nb.to]   = ng;
        queue.enqueue(nb.to, ng + heuristic(nb.to, goal, coords));
      }
    }
  }
  return { found:false, path:[], directions:[], totalCost:0 };
}

module.exports = { aStar, buildGraph };
