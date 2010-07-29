package com.robotacid.ai {
	import com.robotacid.dungeon.DungeonBitmap;
	import flash.display.Graphics;
	/**
	 * Provides a searchable graph for the Brain object
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class DungeonGraph{
		
		public var width:int;
		public var height:int;
		public var nodes:Vector.<Vector.<Node>>;
		
		// A* vars
		private var searchId:int;
		private var open:Vector.<Node>;
		
		// temp vars
		private var node:Node;
		private var adjacentTile:Node;
		
		public function DungeonGraph(bitmap:DungeonBitmap) {
			searchId = 0;
			nodes = new Vector.<Vector.<Node>>();
			width = bitmap.bitmapData.width;
			height = bitmap.bitmapData.height;
			var r:int, c:int;
			for(r = 0; r < height; r++){
				nodes.push(new Vector.<Node>());
				for(c = 0; c < width; c++){
					nodes[r].push(null);
				}
			}
			// there is a node on every surface
			// I am considering ladders and falling as a transition between nodes
			// Characters on ladders will require different rules
			var pixels:Vector.<uint> = bitmap.bitmapData.getVector(bitmap.bitmapData.rect);
			var i:int;
			for(i = width; i < pixels.length - width; i++){
				if(
					(pixels[i] != DungeonBitmap.WALL && (
						pixels[i + width] == DungeonBitmap.PIT ||
						pixels[i + width] == DungeonBitmap.LEDGE ||
						pixels[i + width] == DungeonBitmap.LADDER_LEDGE ||
						pixels[i + width] == DungeonBitmap.WALL
					)) ||
					pixels[i] == DungeonBitmap.LADDER || pixels[i] == DungeonBitmap.LADDER_LEDGE
				){
					r = i / width;
					c = i % width;
					nodes[r][c] = new Node(c, r);
				}
			}
			// connect the nodes
			var n:int;
			for(r = 0; r < height; r++){
				for(c = 0; c < width; c++){
					if(nodes[r][c]){
						n = c + r * width;
						// because we are walking top to bottom, left to right
						// we only look right and down
						if(nodes[r][c + 1]){
							nodes[r][c].connections.push(nodes[r][c + 1]);
							nodes[r][c + 1].connections.push(nodes[r][c]);
						}
						if(
							//pixels[n + width] == DungeonBitmap.PIT ||
							pixels[n + width] == DungeonBitmap.LEDGE
						){
							for(i = r + 1; i < height; i++){
								if(nodes[i][c]){
									nodes[r][c].connections.push(nodes[i][c]);
									break;
								}
							}
						} else if(
							pixels[n + width] == DungeonBitmap.LADDER_LEDGE ||
							pixels[n + width] == DungeonBitmap.LADDER
						){
							nodes[r][c].connections.push(nodes[r + 1][c]);
							nodes[r + 1][c].connections.push(nodes[r][c]);
						}
					}
				}
			}
			
		}
		
		public function drawGraph(gfx:Graphics, scale:Number):void{
			var r:int, c:int, i:int;
			for(r = 0; r < height; r++){
				for(c = 0; c < width; c++){
					if(nodes[r][c]){
						node = nodes[r][c];
						gfx.drawCircle((node.x + 0.5) * scale, (node.y + 0.5) * scale, scale * 0.1);
						for(i = 0; i < node.connections.length; i++){
							gfx.moveTo((node.x + 0.5) * scale, (node.y + 0.5) * scale);
							gfx.lineTo((node.connections[i].x + 0.5) * scale, (node.connections[i].y + 0.5) * scale);
							// arrows
							if(node.connections[i].x == node.x){
								if(node.connections[i].y > node.y){
									gfx.moveTo((node.x + 0.3) * scale, (node.y + 0.7) * scale);
									gfx.lineTo((node.x + 0.5) * scale, (node.y + 0.8) * scale);
									gfx.lineTo((node.x + 0.7) * scale, (node.y + 0.7) * scale);
								} else if(node.connections[i].y < node.y){
									gfx.moveTo((node.x + 0.3) * scale, (node.y + 0.3) * scale);
									gfx.lineTo((node.x + 0.5) * scale, (node.y + 0.2) * scale);
									gfx.lineTo((node.x + 0.7) * scale, (node.y + 0.3) * scale);
								}
							} else if(node.connections[i].y == node.y){
								if(node.connections[i].x > node.x){
									gfx.moveTo((node.x + 0.7) * scale, (node.y + 0.3) * scale);
									gfx.lineTo((node.x + 0.8) * scale, (node.y + 0.5) * scale);
									gfx.lineTo((node.x + 0.7) * scale, (node.y + 0.7) * scale);
								} else if(node.connections[i].x < node.x){
									gfx.moveTo((node.x + 0.3) * scale, (node.y + 0.3) * scale);
									gfx.lineTo((node.x + 0.2) * scale, (node.y + 0.5) * scale);
									gfx.lineTo((node.x + 0.3) * scale, (node.y + 0.7) * scale);
								}
							}
						}
					}
				}
			}
		}
		
		public function drawPath(path:Vector.<Node>, gfx:Graphics, scale:Number):void{
			var i:int;
			gfx.lineStyle(2, 0xFF0000);
			for(i = 0; i < path.length; i++){
				gfx.drawCircle((path[i].x + 0.5) * scale, (path[i].y + 0.5) * scale, scale * 0.25);
				if(i > 0){
					gfx.moveTo((path[i].x + 0.5) * scale, (path[i].y + 0.5) * scale);
					gfx.lineTo((path[i - 1].x + 0.5) * scale, (path[i - 1].y + 0.5) * scale);
				}
			}
		}
		
		/* Returns a vector of nodes describing a route from the start Node to the finish Node
		 *
		 * This algorithm is an implementation of A* with tagging optimisations and a cut off
		 * defined by the variable steps - limiting the search duration eases cpu load */
		public function getPath(start:Node, finish:Node, steps:int = 10):Vector.<Node> {
			
			// the searchId allows the algorithm to mark Nodes as closed or open instead
			// of adding them to arrays and sifting through those arrays all the time
			searchId++;
			
			if (start == finish || !start || !finish) return null;
			
			var i:int, j:int, k:int, c:int, lowest:int;
			var current:Node, adjacentNode:Node;
			
			start.setH(finish);
			open = new Vector.<Node>();
			open.push(start);
			
			var found:Boolean = false;
			// storing the next best option to a complete path allows the search to
			// be aborted early (for difficult or impossible paths)
			var closestGoodNode:Node = start;
			
			for(i = 0; i < steps; i++){
				
				if(open.length == 0) break;
				
				// get nearest open node
				lowest = int.MAX_VALUE;
				c = -1;
				for(j = 0; j < open.length; j++) {
					if (open[j].f < lowest) {
						lowest = open[j].f;
						c = j;
					}
				}
				current = open.splice(c, 1)[0];
				
				if(current.h < closestGoodNode.h) closestGoodNode = current;
				current.closedId = searchId;
				current.openId = 0;
				if (current == finish) {
					found = true;
					break;
				}
				for(j = 0; j < current.connections.length; j++){
					adjacentNode = current.connections[j];
					if(adjacentNode.closedId != searchId){
						if(adjacentNode.openId != searchId) {
							open.push(adjacentNode);
							adjacentNode.openId = searchId;
							adjacentNode.closedId = 0;
							adjacentNode.parent = current;
							adjacentNode.setF(finish);
						} else {
							// double check open nodes for a shorter route
							if(adjacentNode.g > current.g + current.mDist(adjacentNode)){
								adjacentNode.parent = current;
								adjacentNode.setF(finish);
							}
						}
					}
				}
			}
			
			// construct a path
			var path:Vector.<Node> = new Vector.<Node>();
			var pathNode:Node = finish;
			if(!found) pathNode = closestGoodNode;
			
			while(pathNode != start){
				path.push(pathNode);
				pathNode = pathNode.parent;
			}
			
			// it is possible that when no route is found, the start node is the closest
			// node to the target, and so the start node is returned for the Brain to work with
			if(path.length == 0){
				path.push(start);
			}
			
			return path;
		}
		
		
	}

}