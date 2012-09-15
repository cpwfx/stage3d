package
{
	import com.adobe.utils.AGALMacroAssembler;
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	
	// 'multitexture' shader based on http://www.iquilezles.org/apps/shadertoy/ 
	
	/* /////////////////////////////////////////////////////////////////	
	
	vec2 p = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
	// a rotozoom
	vec2 cst = vec2( cos(.5*time), sin(.5*time) );
	mat2 rot = 0.5*cst.x*mat2(cst.x,-cst.y,cst.y,cst.x);
	vec3 col1 = texture2D(tex0,rot*p).xyz;
	
	// scroll
	vec3 col2 = texture2D(tex1,0.5*p+sin(0.1*time)).xyz;
	
	// blend layers
	vec3 col = col2*col1;
	
	gl_FragColor = vec4(col,1.0);
	
	////////////////////////////////////////////////////////////////*/	
	
	[SWF(width="465", height="465", frameRate="60", backgroundColor="#000000")]
	public class Main extends Sprite
	{
		// shader code
		[Embed(source="shader.macro", mimeType="application/octet-stream")]
		protected const ASM:Class;
		
		private var mContext3d:Context3D;
		private var mVertBuffer:VertexBuffer3D;
		private var mIndexBuffer:IndexBuffer3D; 
		private var mProgram:Program3D;
		private var mTexture1:Texture;
		private var mTextureData1:BitmapData;
		private var mTexture2:Texture;
		private var mTextureData2:BitmapData;
		
		private var mMatrix:Matrix3D = new Matrix3D();
		
		
		public function Main()
		{    
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);    
		}
		
		private function init(event:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			initStage();
			loadImage1();
			
			addEventListener(Event.ENTER_FRAME, onTick);
			
			//addChild(new Stats());
		}
		
		private function loadImage1():void {
			var l:Loader = new Loader();
			l.contentLoaderInfo.addEventListener(Event.COMPLETE, onImage1Load);
			l.load(new URLRequest("http://www.iquilezles.org/apps/shadertoy/presets/tex1.jpg"), new LoaderContext(true));
		}
		
		private function onImage1Load(event:Event = null):void
		{
			event.currentTarget.removeEventListener(Event.COMPLETE, onImage1Load);
			var l:Loader = event.currentTarget.loader;
			mTextureData1 = (l.content as Bitmap).bitmapData;
			
			loadImage2();
		}
		
		private function loadImage2():void {
			var l:Loader = new Loader();
			l.contentLoaderInfo.addEventListener(Event.COMPLETE, onImage2Load);
			l.load(new URLRequest("http://www.iquilezles.org/apps/shadertoy/presets/tex2.jpg"), new LoaderContext(true));
		}
		
		private function onImage2Load(event:Event = null):void
		{
			event.currentTarget.removeEventListener(Event.COMPLETE, onImage2Load);
			var l:Loader = event.currentTarget.loader;
			mTextureData2 = (l.content as Bitmap).bitmapData;
			
			stage.stage3Ds[0].addEventListener( Event.CONTEXT3D_CREATE, initStage3d );
			stage.stage3Ds[0].requestContext3D();
		}
		
		private function initStage():void
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
		}
		
		private function initStage3d(event:Event):void
		{
			mContext3d = stage.stage3Ds[0].context3D;        
			mContext3d.enableErrorChecking = true;
			
			mContext3d.configureBackBuffer(stage.stageWidth, stage.stageHeight, 4, true);
			
			var vertices:Vector.<Number> = Vector.<Number>([
				-1.0, -1.0,  0,   0, 0, 
				-1.0,  1.0,  0,   0, 1,
				1.0,  1.0,  0,   1, 1,
				1.0, -1.0,  0,   1, 0  ]);
			
			mVertBuffer = mContext3d.createVertexBuffer(4, 5);
			mVertBuffer.uploadFromVector(vertices, 0, 4);
			mIndexBuffer = mContext3d.createIndexBuffer(6);            
			mIndexBuffer.uploadFromVector (Vector.<uint>([0, 1, 2, 2, 3, 0]), 0, 6);
			
			mTexture1 = mContext3d.createTexture(mTextureData1.width, mTextureData1.height, Context3DTextureFormat.BGRA, true);
			mTexture1.uploadFromBitmapData(mTextureData1);
			
			mTexture2 = mContext3d.createTexture(mTextureData1.width, mTextureData1.height, Context3DTextureFormat.BGRA, true);
			mTexture2.uploadFromBitmapData(mTextureData2);
			
			mContext3d.setVertexBufferAt(0, mVertBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			mContext3d.setVertexBufferAt(1, mVertBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			
			generateMicroProg();
			
			mContext3d.setTextureAt(0, mTexture1);
			mContext3d.setTextureAt(1, mTexture2);
			mContext3d.setProgram(mProgram);
		}
		
		private function generateMicroProg():void
		{
			//same as shader.macro but without comments
			var vertexShaderAssembler : AGALMiniAssembler = new AGALMiniAssembler();
			vertexShaderAssembler.assemble( Context3DProgramType.VERTEX,
				// pos to clipspace
					"m44 op, va0, vc0\n" +
					
				// copy uv
					"mov v0, va1"
			);
			
			/* CONSTANTS: ////////////////////////////////////////////////////
			fc0 = [ 1, 1, 1, 1 ]
			fc1 = [ .5 * mTime, .1 * mTime, 2, 0 ]
			fc2 = [ sin(.5 * mTime), cos(.5 * mTime), sin(.1 * mTime), .5 ] 
			////////////////////////////////////////////////////////////////*/
				
			var fragmentShaderAssembler : AGALMiniAssembler= new AGALMiniAssembler();
			fragmentShaderAssembler.assemble( Context3DProgramType.FRAGMENT,
				
				//Step 1: ft1 = vec2 p = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
					'mov ft1, v0                                    \n' +
					'mul ft1.xy, ft1.xy, fc1.z                      \n' + 
					'div ft1.xy, ft1.xy, fc0.xy                     \n' + 
					'sub ft1.xy, ft1.xy, fc0.x                      \n' +
					
				//Step2: ft2 = vec2 cst = vec2( cos(.5*time), sin(.5*time) );
					'mov ft2.x, fc2.y                               \n' + 
					'mov ft2.y, fc2.x                               \n' + 
					
				//Step3: ft3 = mat2 rot = 0.5*cst.x*mat2(cst.x,-cst.y,cst.y,cst.x);
					'mov ft0.x, fc2.w                               \n' + 
					'mul ft0.x, ft0.x, ft2.x                        \n' + 
					
					'mov ft3.x, ft2.x                               \n' + 
					'mul ft3.x, ft3.x, ft0.x                        \n' + 
					
					'mov ft3.y, fc1.w                               \n' + 
					'sub ft3.y, ft3.y, ft2.y                        \n' + 
					'mul ft3.y, ft3.y, ft0.x                        \n' + 
					
					'mov ft3.z, ft2.y                               \n' + 
					'mul ft3.z, ft3.z, ft0.x                        \n' + 
					
					'mov ft3.w, ft2.x                               \n' + 
					'mul ft3.w, ft3.w, ft0.x                        \n' + 
					
				//Step4: ft4 = rot * p
					'mul ft0.x, ft3.x, ft1.x                        \n' + 
					'mul ft0.y, ft3.y, ft1.y                        \n' + 
					'mul ft0.z, ft3.z, ft1.x                        \n' + 
					'mul ft0.w, ft3.w, ft1.y                        \n' + 
					'add ft4.x, ft0.x, ft0.y                        \n' + 
					'add ft4.y, ft0.z, ft0.w                        \n' + 
					'mov ft4.zw, fc0.zw                             \n' + 
					
				//Step5: ft5 = vec3 col1 = texture2D(tex0,rot*p).xyz;
					'tex ft5, ft4, fs0<2d, repeat, linear, nomip>   \n' + 
					
				//Step6: ft6 = vec3 col2 = texture2D(tex1,0.5*p+sin(0.1*time)).xyz;
					'mov ft0, fc0                                   \n' + 
					'mul ft0, ft1, fc2.w                            \n' + 
					'add ft0, ft0, fc2.z                            \n' + 
					'tex ft6, ft0, fs1<2d, repeat, linear, nomip>   \n' + 
					
				//Step7 ft7 = vec3 col = col2*col1;
					'mul ft7, ft6, ft5                              \n' + 
					
				//Step8 gl_FragColor = vec4(col,1.0);
					'mov oc, ft7'
				);

			mProgram = mContext3d.createProgram();
			mProgram.upload( vertexShaderAssembler.agalcode, fragmentShaderAssembler.agalcode);
		}
		
		
		private var mTime:Number = 0.0;
		private function onTick(event:Event):void
		{
			if ( !mContext3d ) 
				return;
			
			mContext3d.clear ( 0, 0, 0, 1 );
			mContext3d.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mMatrix, true);
			
			//fc0 = [ 1, 1, 1, 1 ]
			mContext3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, Vector.<Number>( [ 1, 1, 1, 1 ]) );
			
			//fc1 = [ .5 * mTime, .1 * mTime, 2, 0 ]
			mContext3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, Vector.<Number>( [ .5 * mTime, .1 * mTime, 2, 0 ]) );
			
			//fc2 = [ sin(.5 * mTime), cos(.5 * mTime), sin(.1 * mTime), .5 ]
			mContext3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, Vector.<Number>( [ Math.sin(.5 * mTime), Math.cos(.5 * mTime), Math.sin(.1 * mTime), .5 ]) );
			
			mContext3d.drawTriangles(mIndexBuffer);
			mContext3d.present();
			
			mTime += .025;
		}
	}
}