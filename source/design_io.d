module design.IO;

import std.stdio;
import std.file;
import std.path ;
import std.range;
import std.algorithm.searching;
import std.regex;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.conv : to;
import std.format;
import std.datetime.systime;
import std.typecons;
import std.math;

class DataFrame {
  enum readItemMode {None, Timestep, NumberOfElements, Bbox, Elements} ;
  enum frameType {None, Atoms, Entries};
  string name ;
  ulong timestep = -1;
  frameType item_type = frameType.None;
  int elements_count = 0;
  string [] elements_header;
  float [][] elements;
  string [3] bbox_header;
  float [2][3] bbox;

  string filepath = "";

  this(string name, string filepath){
    //writeln(filepath);
    this.name = name;
    this.filepath = filepath;
    read_header();
  }

  float [] getColumn(string header){
    int idx2 = cast(int) countUntil(elements_header, header);
    return elements.map!(a => a[idx2]).array();
  }
  
  void clear(){
    //items.clear();
    //filename = "";
    //filepath = "";
    timestep = -1;
    item_type = frameType.None;
    elements_count = 0;
    elements.length = 0;
    elements_header.length = 0;
    //bbox_header.clear();
    //bbox.clear();
  }

  void clear_data(){
    elements.length = 0;
  }

  void read_data(){
    if (is_cache_valid()) {
       read_data_cache();
       return;
    } else {
       read_data_from_txt();
       write_data_cache();
    }
  }

  void read_data_from_txt(){
    if (frameType.None) { 
      read_header();
    }

    auto file = File(filepath);
    auto range = file.byLine();

    bool header = true;
    int idx = 0;

    foreach (line; range)
    {
      if (header){
        auto c2 = matchFirst(line, ctRegex!(`^ITEM: (ATOMS|ENTRIES)\s+(.*)\s+$`));
        if (!c2.empty) {
          header = false;
          idx = 0;

        }
      } else {
        auto ar = line.to!string.split(" ").map!(to!float);
        elements[idx].length = elements_header.length;
        for(int i = 0 ; i< elements[idx].length; i++)
          elements[idx][i] = ar[i];
        //writeln(elements[idx]);
        idx++;
      }
    }
  }


  void read_header(){

    clear();
    scope(failure){ clear(); }

    auto file = File(filepath);
    auto range = file.byLine();

    readItemMode mode = readItemMode.None;

    int idx = 0;
    foreach (line; range)
    {
      if(line[0] == 'I'){
        //writeln(line);  
        if(startsWith(line, "ITEM: TIMESTEP")){
          mode = readItemMode.Timestep;
          idx = 0;
        } else if(startsWith(line, "ITEM: NUMBER OF ATOMS")){
          mode = readItemMode.NumberOfElements; idx = 0;
          item_type = frameType.Atoms;
        } else if(startsWith(line, "ITEM: NUMBER OF ENTRIES")){
          mode = readItemMode.NumberOfElements; idx = 0;
          item_type = frameType.Entries;
        } else if(startsWith(line, "ITEM: ATOMS") || startsWith(line, "ITEM: ENTRIES")){

          auto c2 = matchFirst(line, ctRegex!(`^ITEM: (ATOMS|ENTRIES)\s+(.*)\s+$`));
          if (!c2.empty){
            elements_header = c2[2].to!string.split(" ") ;//.map!(to!string);
            //mode = readItemMode.Elements; idx = 0;
            return;
          }

        } else if(startsWith(line, "ITEM: BOX BOUNDS")){
          auto c2 = matchFirst(line, ctRegex!(`^ITEM: BOX BOUNDS (.*)\s*$`));
          if (!c2.empty){
            mode = readItemMode.Bbox; idx = 0;
            bbox_header = c2[1].to!string.split(" ") ;//.map!(to!string);
            //writeln(bbox_header);
          }
        }
      } else{
        // read line
        switch(mode){ 
          case(readItemMode.None):
            // raise read error
            writeln("read error, line availble in None mode");
            break;
          case(readItemMode.Timestep):
            timestep = line.to!int;
            //writeln(timestep);
            mode = readItemMode.None;
            break;
          case(readItemMode.Bbox):
            {
              auto ar = line.to!string.split(" ").map!(to!float);
              bbox[idx][0] = ar[0];
              bbox[idx][1] = ar[1];
              //writeln(bbox[idx]);
              idx++;
              break;
            }
          case(readItemMode.NumberOfElements):
            // line to float 
            elements_count = line.to!int;
            elements.length = elements_count;
            //writeln(elements_count);
            mode = readItemMode.None;
            break;

          default:
            writeln("read error, line availble in None mode");
          break;
        }

      }

    }

  }


  string cache_file_name(){ 
    return dirName(filepath) ~ "/cache/" ~ baseName(filepath) ~ ".cache";
  }

  void write_data_cache(){
    //writeln("write cache ", cache_file_name() );
    
    auto f = File(cache_file_name, "wb");

    for(int i =0; i < elements.length; i++){
      f.rawWrite((cast(byte*)elements[i].ptr)[0..(elements[i].length * elements[i][0].sizeof)]);
    }

  }

  void read_data_cache(){
    //writeln("read cache ", cache_file_name());

    auto f = File(cache_file_name, "rb");

    for(int i = 0; i < elements.length; i++){

      byte[] buf;
      buf.length = elements_header.length * elements[0][0].sizeof;

      f.rawRead(buf);
      
      elements[i] = [];
      elements[i].length = elements_header.length;
      elements[i] = (cast(float*)buf.ptr)[0..elements_header.length];
      //break;
    }

  }

  bool is_cache_valid(){ 
    if (!cache_file_name().isFile) return false; 

    if (timeLastModified(cache_file_name) >= timeLastModified(filepath, SysTime.min)){
      return true;
    }

    return false;
  }

}

class DataSet {

  string path_prefix;
  
  DataFrame const_frame;

  DataFrame[][int] frames;
  string [] features;

  //path_prefix = "/path/to/data/run1aa.[0]"

  this(string path_prefix){
    this.path_prefix = path_prefix;
    readListing();
  }

  void readListing(){
    writeln(dirName(path_prefix));
    // test for const
    if (!(path_prefix ~ ".0").isFile){
      //raise io error
      writeln("eRor no .0");
    }

    if (!(path_prefix ~ ".0.const").isFile){
      //raise io error
      writeln("eRor no .0.const");
    }

    // .0.const
    const_frame = new DataFrame("const", path_prefix ~ ".0.const");

    // read features
    foreach (string name; dirEntries(dirName(path_prefix),"*.0.*",  SpanMode.shallow) )
    {
      auto c2 = matchFirst(name, ctRegex!(`\.0\.(.*)$`));
      if (!c2.empty){
        if (c2[1].to!string != "const"){
          ++features.length;
          features[features.length - 1] = c2[1].to!string;
        }
      }
    }

    //writeln(features);
    //writeln(dirEntries(dirName(path_prefix),  SpanMode.shallow));

    int [] timesteps;
    foreach (string name; dirEntries(dirName(path_prefix),"*.mean",  SpanMode.shallow) )
    {
      auto c2 = matchFirst(name, ctRegex!(`\.(\d+)\.mean$`));
      if (!c2.empty){
        ++timesteps.length;
        timesteps[timesteps.length - 1] = c2[1].to!int;
      }
    }

    timesteps.sort;

    foreach(int ts; timesteps){
      frames[ts] = [];
      frames[ts].length = features.length + 1;

      for(int i; i< features.length; i++){
        frames[ts][i] = new DataFrame(features[i], path_prefix ~ ".%d.%s".format(ts,features[i]));
      }

      frames[ts][features.length] = new DataFrame("", path_prefix ~ ".%d".format(ts));

    }    
  }

  int [] getTimeSteps(){
    return frames.keys();
  }

  string [] getFeaturesList(){
    string [] fcs;

    fcs ~= (const_frame.elements_header.map!(a => "const." ~ a).array() );

    foreach (ts, frame; frames)
    {
      foreach(f; frame){
        fcs ~= (f.elements_header.map!(a => f.name ~"." ~ a).array() );
        //writeln(f.elements_count);
      }
      break;
    }

    return fcs;
  }

  Tuple!(int,int) getFeatureIdx(string featureName){

    if (startsWith(featureName,"const.")){
      // "const.radius"
      auto c2 = matchFirst(featureName, ctRegex!(`^const\.(.*)$`));
      if (!c2.empty){
        string s = c2[1].to!string;
        int idx = cast(int)countUntil(const_frame.elements_header, s);
        return tuple(-1,idx);
      } // raise 
    } else if(startsWith(featureName,".")){
      auto c2 = matchFirst(featureName, ctRegex!(`^\.(.*)$`));
      if (!c2.empty){
        string s = c2[1].to!string;
        int idx = cast(int)countUntil(frames[0][$-1].elements_header, s);
        return tuple(cast(int)features.length,idx);
      } // raise 
    } else {
      auto c2 = matchFirst(featureName, ctRegex!(`^([a-z0-9A-Z_]+)\.(.*)$`));
      if (!c2.empty){

        writeln(c2);

        string feat = c2[1].to!string;
        string head = c2[2].to!string;

        int idx1 = cast(int)countUntil(features, feat);
        if (idx1 == -1) return tuple(-999,-999);

        int idx2 = cast(int)countUntil(frames[0][idx1].elements_header, head);

        return tuple(idx1,idx2);

      }
    }

    return tuple(-999,-999);
  }
  
  DataFrame getFrame(int timeStep, string featureIdx){

    auto idx2 = countUntil(features, featureIdx);
    if (featureIdx == "const"){
      return const_frame;
    } else if (featureIdx == ""){
      return frames[timeStep][features.length];
    } else if (idx2 > 0){
      return frames[timeStep][idx2];
    }
    auto idx = getFeatureIdx(featureIdx);
    return getFrame(timeStep, idx[0]);
  }

  DataFrame getFrame(int timeStep, int featureIdx){
    if (featureIdx == -1 ) {
      return const_frame;
    } else if (featureIdx <= features.length) {
      return frames[timeStep][featureIdx];
    }
    return null;
  }
}

float scale2Bbox(float v, float [2] ext){
  return ext[0] + (v* (ext[1] - ext[0]));
}

class DataSetVisualizator{

  DataSet ds;
  int [] timeSteps;

  float [] radius;
  float [][int] cachedFloatFrames;

  this(DataSet ds){
    this.ds = ds;
    timeSteps = ds.frames.keys.sort.array();
    getRadius();
  }

  void getRadius(){
    auto f = ds.getFrame(0,"const");
    f.read_data();
    //writeln(f.elements_count, " id: ", ds.getFrame(0,"const").elements[0][0]);
    radius = ds.getFrame(0,"const").getColumn("radius");
    f.clear_data();
  }

  float [] getFrame(int ts){
    {
      auto dc = cachedFloatFrames.get(ts, []);
      if (!dc.empty) return dc;
    }

    auto f = ds.getFrame(ts,"");
    f.read_data();

    //writeln(f.bbox);
    //writeln(ts, " - " , f.elements_count, " id: " , f.elements[0][0]);  
    auto xs = f.getColumn("xs");
    auto ys = f.getColumn("ys");

    auto fx = f.getColumn("fx");
    auto fy = f.getColumn("fy");
    //auto omegaz = f.getColumn("omegaz");

    float[] data;
    static int len_ar = 4;
    data.length = radius.length * len_ar;

    foreach (i; 0..radius.length) {
      auto color = sqrt( (fx[i] * fx[i]) + (fy[i] * fy[i]) );
      data[i*len_ar..((i+1) * len_ar)] = [scale2Bbox(xs[i], f.bbox[0]), scale2Bbox(ys[i], f.bbox[1]), radius[i], color];
    }

    f.clear_data();
    cachedFloatFrames[ts] = data;
    return cachedFloatFrames[ts];
  }

}

