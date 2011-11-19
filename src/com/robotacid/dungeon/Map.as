﻿package com.robotacid.dungeon {
	import com.robotacid.engine.ChaosWall;
	import com.robotacid.engine.Character;
	import com.robotacid.engine.MapTileConverter;
	import com.robotacid.engine.Player;
	import com.robotacid.engine.Portal;
	import com.robotacid.geom.Pixel;
	import com.robotacid.gfx.Renderer;
	import com.robotacid.util.array.randomiseArray;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * This is the random map generator
	 *
	 * The layout for every dungeon is calculated in here.
	 * 
	 * DungeonBitmap creates the passage ways and creates a connectivity graph to place ladders and ledges
	 * the convertDungeonBitmap method converts that data into references to graphics and entities
	 * within that method Content.populateLevel distributes monsters and treasure
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class Map {
		
		public static var g:Game;
		public static var renderer:Renderer;
		
		public var level:int;
		public var type:int;
		public var width:int;
		public var height:int;
		public var start:Pixel;
		public var stairsUp:Pixel;
		public var stairsDown:Pixel;
		public var portals:Vector.<Pixel>;
		
		public var bitmap:DungeonBitmap;
		
		private var i:int, j:int;
		
		public var layers:Array;
		
		// types
		public static const MAIN_DUNGEON:int = 0;
		public static const SIDE_DUNGEON:int = 1;
		
		// layers
		public static const BACKGROUND:int = 0;
		public static const BLOCKS:int = 1;
		public static const ENTITIES:int = 2;
		
		public static const LAYER_NUM:int = 3;
		
		public static const BACKGROUND_WIDTH:int = 8;
		public static const BACKGROUND_HEIGHT:int = 8;
		
		public static const ITEMS:Array = [38, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51];
		
		public function Map(level:int, type:int = MAIN_DUNGEON) {
			this.level = level;
			this.type = type;
			layers = [];
			portals = new Vector.<Pixel>();
			if(type == MAIN_DUNGEON){
				if(level){
					if(level > 0){
						bitmap = new DungeonBitmap(level);
						width = bitmap.width;
						height = bitmap.height;
						convertDungeonBitmap(bitmap.bitmapData);
					} else {
						createTestBed();
					}
				} else {
					createOverworld();
				}
			} else if(type == SIDE_DUNGEON){
				var sideDungeonSize:int = 1 + (Number(level) / 10);
				bitmap = new DungeonBitmap(sideDungeonSize);
				width = bitmap.width;
				height = bitmap.height;
				convertDungeonBitmap(bitmap.bitmapData);
			}
			createBackground();
			//bitmap.scaleX = bitmap.scaleY = 4;
			//g.addChild(bitmap);
			
		}
		
		/* Create the test bed
		 *
		 * This is a debugging playground for testing new content and trying to lure consistent
		 * bugs out into the open (which is nigh on fucking impossible in a procedural world)
		 */
		public function createTestBed():void{
			
			bitmap = new DungeonBitmap(0);
			
			width = bitmap.width;
			height = bitmap.height;
			// background
			layers.push(createGrid(null, width, height));
			// blocks - start with a full grid
			layers.push(createGrid(MapTileConverter.WALL, width, height));
			// game objects
			layers.push(createGrid(null, width, height));
			
			fill(0, 1, 0, width-2, height-1, layers[BLOCKS]);
			
			// insert test code for items and such here
			//layers[ENTITIES][9][7] = 62;
			//layers[ENTITIES][44][6] = 22;
			//layers[ENTITIES][44][8] = 22;
			
			// access points
			setStairsUp(15, height - 2);
			setStairsDown(10, height - 2);
			
			setValue(9, height - 2, BLOCKS, MapTileConverter.WALL);
			
			
			// create trap
			//setValue(13, height - 5, BLOCKS, 1);
			//setValue(13, height - 1, ENTITIES, 56);
			
			setValue(11, height - 2, BLOCKS, MapTileConverter.LADDER);
			setValue(11, height - 3, BLOCKS, MapTileConverter.LADDER);
			setValue(11, height - 4, BLOCKS, MapTileConverter.LADDER);
			
			// monster debug
			//createCharacter(10, height - 2, 2, 1);
			//createCharacter(9, height - 2, 2, 1);
			//createCharacter(8, height - 2, 2, 1);
			//createCharacter(5, height - 2, 2, 1);
			//createCharacter(4, height - 2, 2, 1);
			//createCharacter(3, height - 2, 2, 1);
			//createCharacter(2, height - 2, 2, 1);
			//createCharacter(15, height - 2, 2, 1);
			
			// critter debug
			//setValue(5, height - 2, ENTITIES, 62);
			
			
			createChaosWalls(bitmap.bitmapData.getVector(bitmap.bitmapData.rect));
			layers[ENTITIES][height - 2][1] = new ChaosWall(1, height - 2);
			layers[BLOCKS][height - 2][1] = MapTileConverter.WALL;
			
			//createSecretWall(15, height - 2);
			
			
			//layers[BLOCKS][40][10] = 1;
			//layers[BLOCKS][44][10] = 1;
		}
		
		
		
		/* This is where we convert our map template into a dungeon proper made of tileIds and other
		 * information
		 */
		public function convertDungeonBitmap(bitmapData:BitmapData):void{
			width = bitmapData.width;
			height = bitmapData.height;
			// background
			layers.push(createGrid(null, bitmapData.width, bitmapData.height));
			// blocks - start with a full grid
			layers.push(createGrid(MapTileConverter.WALL, bitmapData.width, bitmapData.height));
			// game objects
			layers.push(createGrid(null, bitmapData.width, bitmapData.height));
			
			var pixels:Vector.<uint> = bitmapData.getVector(bitmapData.rect);
			
			// create ladders, ledges and features
			
			// do a first pass to set up pit-traps and secrets and remove them from pixels[]
			// it makes the convoluted ledge/ladder checks simpler
			var r:int, c:int;
			for(i = width; i < pixels.length - width; i++){
				c = i % width;
				r = i / width;
				if(pixels[i] == DungeonBitmap.PIT){
					layers[ENTITIES][r][c] = MapTileConverter.PIT;
					pixels[i] = DungeonBitmap.WALL;
				} else if(pixels[i] == DungeonBitmap.SECRET){
					layers[ENTITIES][r][c] = MapTileConverter.SECRET_WALL;
					pixels[i] = DungeonBitmap.WALL;
				}
			}
			// now for ladders, ledges and empty spaces
			for(i = width; i < pixels.length - width; i++){
				c = i % width;
				r = i / width;
				if(pixels[i] == DungeonBitmap.EMPTY && pixels[i + width] == DungeonBitmap.LADDER_LEDGE){
					layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP;
				} else if(pixels[i] == DungeonBitmap.LEDGE && pixels[i + width] == DungeonBitmap.LADDER_LEDGE){
					
					if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_END_LEFT;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_START_RIGHT_END;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_START_LEFT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_SINGLE;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_START_RIGHT;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_END_RIGHT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_START_LEFT_END;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_TOP_LEDGE_MIDDLE;
					}
					
				} else if(pixels[i] == DungeonBitmap.LADDER_LEDGE){
					
					if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_END_LEFT;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_START_RIGHT_END;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_START_LEFT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_SINGLE;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_START_RIGHT;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_END_RIGHT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_START_LEFT_END;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LADDER_LEDGE_MIDDLE;
					}
					
				} else if(pixels[i] == DungeonBitmap.LADDER){
					layers[BLOCKS][r][c] = MapTileConverter.LADDER;
				} else if(pixels[i] == DungeonBitmap.LEDGE){
					
					if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_END_LEFT;
						
					} else if((pixels[i - 1] == DungeonBitmap.EMPTY || pixels[i - 1] == DungeonBitmap.LADDER) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_START_RIGHT_END;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_START_LEFT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_SINGLE;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && pixels[i + 1] == DungeonBitmap.WALL){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_START_RIGHT;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_END_RIGHT;
						
					} else if(pixels[i - 1] == DungeonBitmap.WALL && (pixels[i + 1] == DungeonBitmap.EMPTY || pixels[i + 1] == DungeonBitmap.LADDER)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_START_LEFT_END;
						
					} else if((pixels[i - 1] == DungeonBitmap.LEDGE || pixels[i - 1] == DungeonBitmap.LADDER_LEDGE) && (pixels[i + 1] == DungeonBitmap.LEDGE || pixels[i + 1] == DungeonBitmap.LADDER_LEDGE)){
						
						layers[BLOCKS][r][c] = MapTileConverter.LEDGE_MIDDLE;
					}
					
				} else if(pixels[i] == DungeonBitmap.EMPTY){
					layers[BLOCKS][r][c] = 0;
				}
			}
			
			// create access points
			if(type == MAIN_DUNGEON){
				createAccessPoint(Portal.STAIRS, "up");
				var portalXMLs:Vector.<XML> = g.content.getPortals(level);
				var portalType:int;
				for(i = 0; i < portalXMLs.length; i++){
					portalType = portalXMLs[i].@type;
					createAccessPoint(portalType, null, portalXMLs[i]);
				}
				createAccessPoint(Portal.STAIRS, "down");
				
			} else if(type == SIDE_DUNGEON){
				createAccessPoint(Portal.STAIRS, "up", Portal.getReturnPortalXML());
			}
			
			// a good dungeon needs to be full of loot and monsters
			// in comes the content manager to mete out a decent amount of action and reward per level
			// content manager stocks are limited to avoid scumming
			g.content.populateLevel(level, bitmap, layers);
			
			// now add some flavour
			createChaosWalls(pixels);
			setDartTraps();
			addCritters();
		}
		
		/* Create the overworld
		 *
		 * The overworld is present to create a contrast with the dungeon. It is in colour and so
		 * are you. You can wield no weapons here and your minion is unseen
		 * There is a health stone for restoring health and a grindstone -
		 * an allegory of improving yourself in the real world as opposed to a fantasy where
		 * you kill people to better yourself
		 */
		public function createOverworld():void{
			
			bitmap = new DungeonBitmap(0);
			
			width = bitmap.width;
			height = bitmap.height;
			layers.push(createGrid(null, width, height));
			// blocks - start with a full grid
			layers.push(createGrid(1, width, height));
			// game objects
			layers.push(createGrid(null, width, height));
			
			fill(0, 1, 0, width-2, height-1, layers[BLOCKS]);
			
			// create the grindstone and healstone
			layers[BLOCKS][height - 2][1] = 1;
			layers[ENTITIES][height - 2][1] = 60;
			layers[BLOCKS][height - 2][width - 2] = 1;
			layers[ENTITIES][height - 2][width - 2] = 61;
			
			var portalXMLs:Vector.<XML> = g.content.getPortals(level);
			if(portalXMLs.length){
				// given that there can only be one type of portal on the overworld - the rogue's portal
				// we create the rogue's portal here
				setPortal(17, height - 2, portalXMLs[0]);
			}
			
			setStairsDown(12, height - 2);
			
			// the player may have left content on the overworld as a sort of bank
			g.content.populateLevel(0, bitmap, layers);
		}
		
		/* Creates a random parallax background */
		public function createBackground():void{
			var bitmapData:BitmapData;
			if(level == 0){
				var bitmap:Bitmap = new g.library.OverworldB;
				bitmapData = bitmap.bitmapData;
			} else {
				bitmapData = new BitmapData(Game.SCALE * BACKGROUND_WIDTH, Game.SCALE * BACKGROUND_HEIGHT, true, 0x00000000);
				var source:BitmapData;
				var point:Point = new Point();
				var x:int, y:int;
				for(y = 0; y < BACKGROUND_HEIGHT * 0.5; y ++){
					for(x = 0; x < BACKGROUND_WIDTH * 0.5; x ++){
						source = renderer.backgroundBitmaps[g.random.rangeInt(renderer.backgroundBitmaps.length)].bitmapData;
						point.x = x * Game.SCALE * 2;
						point.y = y * Game.SCALE * 2;
						bitmapData.copyPixels(source, source.rect, point);
					}
				}
			}
			renderer.backgroundBitmapData = bitmapData;
		}
		
		public function createAccessPoint(type:int, stairs:String = null, xml:XML = null):void{
			// a portal on a ledge looks crap, so we try hard to avoid this
			var tryToAvoidPortalOnLedge:int = 100;
			var index:int = 0;
			var ex:int, ey:int;
			var tries:int = 0;
			var rooms:Vector.<Room> = bitmap.rooms;
			if(stairs){
				if(stairs == "up") rooms.sort(sortRoomsTopWards);
				else if(stairs == "down") rooms.sort(sortRoomsBottomWards);
			}
			var portalRoom:Room = rooms[index];
			
			ey = portalRoom.y + 1;
			do{
				if(tries++ > 200){
					if(index == rooms.length - 1) throw new Error("failed to create portal, stairs: " + stairs);
					else {
						tries = 0;
						index++;
						portalRoom = rooms[index];
					}
				}
				ex = portalRoom.x + g.random.rangeInt(portalRoom.width);
				
				// cycle through y positions in the room trying to find a good spot
				if(layers[BLOCKS][ey + 1][ex] == 0 || bitmap.bitmapData.getPixel32(ex, ey + 1) == DungeonBitmap.LEDGE || bitmap.bitmapData.getPixel32(ex, ey + 1) == DungeonBitmap.LADDER_LEDGE) ey++;
				if(layers[BLOCKS][ey][ex] == 1) ey = portalRoom.y;
				
			} while(!goodPortalPosition(ex, ey, (tryToAvoidPortalOnLedge--) > 0));
			if(type == Portal.STAIRS){
				if(stairs == "up") setStairsUp(ex, ey);
				else if(stairs == "down") setStairsDown(ex, ey);
			} else {
				setPortal(ex, ey, xml);
			}
		}
		
		// room sorting callbacks
		private function sortRoomsTopWards(a:Room, b:Room):Number{
			if(a.y < b.y) return -1;
			else if(a.y > b.y) return 1;
			return 0;
		}
		private function sortRoomsBottomWards(a:Room, b:Room):Number{
			if(a.y > b.y) return -1;
			else if(a.y < b.y) return 1;
			return 0;
		}
		
		/* Creates a stairway up */
		public function setStairsUp(x:int, y:int):void{
			layers[ENTITIES][y][x] = MapTileConverter.STAIRS_UP;
			stairsUp = new Pixel(x, y);
			if(isPortalToPreviousLevel(x, y, Portal.STAIRS, level - 1)) start = stairsUp;
		}
		
		/* Creates a stairway down */
		public function setStairsDown(x:int, y:int):void{
			layers[ENTITIES][y][x] = MapTileConverter.STAIRS_DOWN;
			stairsDown = new Pixel(x, y);
			if(isPortalToPreviousLevel(x, y, Portal.STAIRS, level + 1)) start = stairsDown;
		}
		
		/* Creates a portal */
		public function setPortal(x:int, y:int, xml:XML):void{
			var p:Pixel = new Pixel(x, y);
			var portal:Portal = Content.convertXMLToObject(x, y, xml);
			if(level == 0 && portal.type == Portal.DUNGEON){
				portal.maskOverworldPortal();
			}
			layers[ENTITIES][y][x] = portal;
			if(isPortalToPreviousLevel(x, y, int(xml.@type), int(xml.@targetLevel))) start = p;
			portals.push(p);
		}
		
		/* Is this portal going to be the entry point for the level?
		 * 
		 * Map.start and Game.entrance are used by the game engine to set the camera and entry point for the level
		 * which is why this query belongs in a function to be called by various elements
		 * 
		 * The logic follows: does this portal lead to the last level you were on */
		public static function isPortalToPreviousLevel(x:int, y:int, type:int, targetLevel:int):Boolean{
			if(type == Portal.STAIRS){
				if(Player.previousPortalType == Portal.STAIRS && Player.previousLevel == targetLevel) return true;
			} else if(type == Portal.ROGUE ){
				if(Player.previousPortalType == Portal.DUNGEON && Player.previousLevel == 0) return true;
			} else if(type == Portal.ITEM){
				if(Player.previousPortalType == Portal.DUNGEON && Player.previousLevel > 0) return true;
			} else if(type == Portal.DUNGEON){
				if(Player.previousPortalType == Portal.ROGUE || Player.previousPortalType == Portal.ITEM) return true;
			}
			return false;
		}
		
		/* Getting a good position for the portals is complex.
		 * We want clear spaces to each side and solid floor below - preferably walls below on stairs down
		 * - hence the mess in this method */
		public function goodPortalPosition(x:int, y:int, ledgeAllowed:Boolean = true):Boolean{
			var p:Pixel;
			for(var i:int = 0; i < portals.length; i++){
				p = portals[i];
				if(p.x == x && p.y == y) return false;
			}
			if(stairsUp && stairsUp.x == x && stairsUp.y == y) return false;
			if(stairsDown && stairsDown.x == x && stairsDown.y == y) return false;
			var pos:uint = bitmap.bitmapData.getPixel32(x, y);
			var posBelow:uint = bitmap.bitmapData.getPixel32(x, y + 1);
			var posLeft:uint =  bitmap.bitmapData.getPixel32(x - 1, y);
			var posRight:uint =  bitmap.bitmapData.getPixel32(x + 1, y);
			if(bitmap.leftSecretRoom && bitmap.leftSecretRoom.contains(x, y)) return false;
			if(bitmap.rightSecretRoom && bitmap.rightSecretRoom.contains(x, y)) return false;
			return (
				(posLeft != DungeonBitmap.WALL && posRight != DungeonBitmap.WALL) &&
				(posBelow == DungeonBitmap.WALL || (posBelow == DungeonBitmap.LEDGE && ledgeAllowed)) &&
				(pos == DungeonBitmap.EMPTY || pos == DungeonBitmap.LEDGE)
			);
		}
		
		/* Adds critters to the level - decorative entites that squish on contact */
		public function addCritters():void{
			
			// create critter bias
			var ratios:Array = [];
			var total:Number = g.random.value();
			ratios.push(1 - total);
			var temp:Number = total;
			total -= g.random.range(total);
			ratios.push(temp - total);
			ratios.push(total);
			randomiseArray(ratios, g.random);
			
			var r:int, c:int, critterNum:int, breaker:int;
			critterNum = Math.sqrt(width * height) * ratios[0];
			breaker = 0;
			while(critterNum){
				r = 1 + g.random.range(bitmap.height - 1);
				c = 1 + g.random.range(bitmap.width - 1);
				if(!layers[Map.ENTITIES][r][c] && layers[Map.BLOCKS][r][c] != 1 && (bitmap.bitmapData.getPixel32(c, r + 1) == DungeonBitmap.LEDGE || layers[Map.BLOCKS][r + 1][c] == 1)){
						
					layers[Map.ENTITIES][r][c] = MapTileConverter.RAT;
					critterNum--;
				}
				if((breaker++) > 1000) break;
			}
			critterNum = Math.sqrt(width * height) * ratios[1];
			breaker = 0;
			while(critterNum){
				r = 1 + g.random.range(bitmap.height - 1);
				c = 1 + g.random.range(bitmap.width - 1);
				if(!layers[Map.ENTITIES][r][c] && layers[Map.BLOCKS][r][c] != 1 && layers[Map.BLOCKS][r - 1][c] == 1 && bitmap.bitmapData.getPixel32(c, r - 1) != DungeonBitmap.PIT){
						
					layers[Map.ENTITIES][r][c] = MapTileConverter.SPIDER;
					critterNum--;
				}
				if((breaker++) > 1000) break;
			}
			critterNum = Math.sqrt(width * height) * ratios[2];
			breaker = 0;
			while(critterNum){
				r = 1 + g.random.range(bitmap.height - 1);
				c = 1 + g.random.range(bitmap.width - 1);
				if(!layers[Map.ENTITIES][r][c] && layers[Map.BLOCKS][r][c] != 1 && layers[Map.BLOCKS][r - 1][c] == 1 && bitmap.bitmapData.getPixel32(c, r - 1) != DungeonBitmap.PIT){
						
					layers[Map.ENTITIES][r][c] = MapTileConverter.BAT;
					critterNum--;
				}
				if((breaker++) > 1000) break;
			}
		}
		
		/* Sprinkle on some chaos walls to make exploring weirder */
		public function createChaosWalls(pixels:Vector.<uint>):void{
			ChaosWall.init(width, height);
			
			// we only put chaos walls in corridors, so we need a stretch of three wall blocks to
			// either side of the chaos wall
			var i:int, r:int, c:int;
			for(i = width; i < pixels.length - width; i++){
				c = i % width;
				r = i / width;
				if(c > 0 && c < width - 1 && pixels[i] == DungeonBitmap.EMPTY){
					if(
						// horizontal corridor
						(
							pixels[(i - width) - 1] == DungeonBitmap.WALL && 
							pixels[i - width] == DungeonBitmap.WALL && 
							pixels[(i - width) + 1] == DungeonBitmap.WALL && 
							pixels[(i + width) - 1] == DungeonBitmap.WALL && 
							pixels[i + width] == DungeonBitmap.WALL && 
							pixels[(i + width) + 1] == DungeonBitmap.WALL
						) ||
						// vertical corridor
						(
							pixels[(i - width) - 1] == DungeonBitmap.WALL && 
							pixels[i - 1] == DungeonBitmap.WALL && 
							pixels[(i + width) - 1] == DungeonBitmap.WALL && 
							pixels[(i - width) + 1] == DungeonBitmap.WALL && 
							pixels[i + 1] == DungeonBitmap.WALL && 
							pixels[(i + width) + 1] == DungeonBitmap.WALL
						)
					){
						if(g.random.value() < 0.4){
							layers[ENTITIES][r][c] = new ChaosWall(c, r);
							layers[BLOCKS][r][c] = MapTileConverter.WALL;
						}
					}
				}
			}
		}
		
		/* This adds dart traps to the level */
		public function setDartTraps():void{
			var numTraps:int = level;
			var trapPositions:Vector.<Pixel> = new Vector.<Pixel>();
			var pixels:Vector.<uint> = bitmap.bitmapData.getVector(bitmap.bitmapData.rect);
			var mapWidth:int = bitmap.bitmapData.width;
			for(i = mapWidth; i < pixels.length - mapWidth; i++){
				if((pixels[i] == DungeonBitmap.WALL) && (pixels[i - mapWidth] == DungeonBitmap.EMPTY || pixels[i - mapWidth] == DungeonBitmap.LEDGE)){
					for(j = i - mapWidth; j > mapWidth; j -= mapWidth){
						// no combining ladders or pit traps with dart traps
						// it confuses the trap and it's unfair to have to climb a ladder into a dart
						if(pixels[j] == DungeonBitmap.LADDER || pixels[j] == DungeonBitmap.LADDER_LEDGE || pixels[j] == DungeonBitmap.PIT){
							break;
						} else if(pixels[j] == DungeonBitmap.WALL){
							trapPositions.push(new Pixel(i % mapWidth, i / mapWidth));
							break;
						}
					}
				}
			}
			
			while(numTraps > 0 && trapPositions.length > 0){
				var trapIndex:int = g.random.range(trapPositions.length);
				var trapPos:Pixel = trapPositions[trapIndex];
				layers[ENTITIES][trapPos.y][trapPos.x] = g.random.value() < 0.5 ? MapTileConverter.POISON_DART : MapTileConverter.TELEPORT_DART;
				numTraps--;
				trapPositions.splice(trapIndex, 1);
				
			}
		}
		
		/* Debugging or set-piece method */
		public function createCharacter(x:int, y:int, name:int, level:int):void{
			var characterXML:XML = <character />;
			characterXML.@name = name;
			characterXML.@type = Character.MONSTER;
			characterXML.@level = level;
			layers[ENTITIES][y][x] = Content.convertXMLToObject(x, y, characterXML);
		}
		
		public function setValue(x:int, y:int, z:int, value:*):void{
			layers[z][y][x] = value;
		}
		
		public function getValue(x:int, y:int, z:int):*{
			return layers[z][y][x];
		}
		
		/* Creates a secret wall that can be broken through */
		public function createSecretWall(x:int, y:int):void{
			layers[ENTITIES][y][x] = MapTileConverter.SECRET_WALL;
			layers[BLOCKS][y][x] = 1;
		}
		
		/* Used to clear out a section of a grid or flood it with a particular tile type */
		public function fill(index:int, x:int, y:int, width:int, height:int, grid:Array):void{
			var r:int, c:int;
			for(r = y; r < y + height; r++){
				for(c = x; c < x + width; c++){
					grid[r][c] = index;
				}
			}
		}
		
		public static function createGrid(base:*, width:int, height:int):Array {
			var r:int, c:int, a:Array = [];
			for(r = 0; r < height; r++) {
				a.push([]);
				for(c = 0; c < width; c++) {
					a[r].push(base);
				}
			}
			return a;
		}
		
		/* is this pixel sitting on the edge of the map? it will likely cause me trouble if it is... */
		public static function onEdge(pixel:Pixel, width:int, height:int):Boolean{
			return pixel.x<= 0 || pixel.x >= width-1 || pixel.y <= 0 || pixel.y >= height-1;
		}
	}
	
}