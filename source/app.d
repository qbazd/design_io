module design.test_io;

import std.string;
import std.stdio;
import design.IO;
import std.algorithm;
import std.math;


void main()
{
    //auto df = new DataFrame("../shearbreak.res/run1aa.0");
//    writeln(df.elements[0]);
//    writeln(df.elements[1]);
//    writeln(df.elements[2]);
    
    auto ds = new DataSet("../shearbreak.res/run1aa");

    //writeln(ds.frames.length);
    //writeln(ds.features);
    writeln(ds.const_frame.elements_header);
    writeln(ds.const_frame.bbox);

    writeln(ds.getFeaturesList());
    writeln(ds.getFeatureIdx("const.id"));
    writeln(ds.getFeatureIdx(".tqz"));
    writeln(ds.getFeatureIdx("bonds.c_4d[5]"));


    auto dsv = new DataSetVisualizator(ds);

    float x;

    for(int i =0 ; i< 100; i++){
      writeln(i);
      string name = strip(stdin.readln());

      foreach(ts; dsv.timeSteps ){
        auto f = dsv.getFrame(ts);
        x = f[0];
        //writeln(dsv.getFrame(ts));
      }
    }

/+
    foreach (ts, frame; ds.frames)
    {
      writeln(ts);
      writeln(frame[0].bbox);
      foreach(f; frame){
        writeln(f.elements_header.map!(a => f.name ~"." ~ a) );
        writeln(f.elements_count);
      }
      break;
    }
+/

    //string name = strip(stdin.readln());
    //writeln(name);
    //writeln(dr.items);
    //print dr.items
    //#print len(dr.items.lines)
/+    path = '../shearbreak.res'

    sims = DESIgnDirReader.list_sims(path)
    print list(sims)[0]

    des_dir = DESIgnDirReader(path + '/' + list(sims)[0])
    des_dir.load_schema()
    des_dir.check_consistency()

	writeln("Edit source/app.d to start your project.");
+/
}
