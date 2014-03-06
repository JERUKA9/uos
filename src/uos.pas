unit uos;
{.$DEFINE library}   // uncomment it for building uos library
{.$DEFINE ConsoleApp} // if FPC version < 2.7.1 uncomment it for console application

{*******************************************************************************
*                  United Openlibraries of Sound ( uos )                       *
*                  --------------------------------------                      *
*                                                                              *
*          United procedures to access Open Sound (IN/OUT) libraries           *
*                                                                              *
*              With Big contributions of (in alphabetic order)                 *
*      BigChimp, Blaazen, Sandro Cumerlato, Dibo, KpjComp, Leledumbo.          *
*                                                                              *
*                 Fred van Stappen /  fiens@hotmail.com                        *
*                                                                              *
*                                                                              *
********************************************************************************
*  first changes:  2012-07-20   (first shot)                                   *
*  second changes: 2012-07-31   (mono thread, only one stream)                 *
*  3 th changes: 2012-11-13  (mono thread, multi streams)                      *
*  4 th changes: 2012-11-14  (multi threads, multi streams)                    *
*  5 th changes: 2012-11-27 (event pause, position, volume, reverse)           *
*  6 th changes: 2012-12-31 (Class/Oop look, DSP, multi IN/OUT)                *
*  7 th changes: 2013-01-12 (Float resolution for all, new DSP proc)           *
*  8 th changes: 2013-01-21 (Record, Direct Wire, Save to file, new DSP proc)  *
*  9 th changes: 2013-01-28 (FFT, Filters HighPass, LowPass, BandSelect,       *
*                                    BandReject, BandPass)                     *
* 10 th changes: 2013-02-02 (Dibo's time procedures, Max Karpushin add         *
*                                 reference counting in PortAudio)             *
* 11 th changes: 2013-05-03 (Fully FP/fpGUI/Lazarus compatible)                *
* 12 th changes: 2014-10-01 (Added GetLevel procedure)                         *
* 13 th changes: 2014-02-01 (Added Plugin + Dynamic Buffer => uos version 1.0) *
*                                                                              *
********************************************************************************}

{
    Copyright (C) 2014  Fred van Stappen

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

}

interface

uses
   {$IF (FPC_FULLVERSION >= 20701) or DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Windows) or DEFINED(Library)}
     {$else}
  fpg_base, fpg_main,  //// for fpGUI
    {$endif}
  Classes, ctypes, Math, SysUtils, uos_portaudio,
  uos_LibSndFile, uos_Mpg123, uos_soundtouch;

type
  TDArFloat = array of cfloat;
  TDArShort = array of cInt16;
  TDArLong = array of cInt32;

  PDArFloat = ^TDArFloat;
  PDArShort = ^TDArShort;
  PDArLong = ^TDArLong;

  {$IF not DEFINED(windows)}
  THandle = pointer;
  TArray = single;
  {$endif}

type
  Tuos_LoadResult = record
    PAloadError: shortint;
    SFloadError: shortint;
    MPloadError: shortint;
    STloadError: shortint;
    PAinitError: integer;
    MPinitError: integer;
  end;

type
  Tuos_Init = class(TObject)
  public
  constructor Create;
  private
    PA_FileName: ansistring; // PortAudio
    SF_FileName: ansistring; // SndFile
    MP_FileName: ansistring; // Mpg123
    Plug_ST_FileName: ansistring; // Plugin SoundTouch
    DefDevOut: PaDeviceIndex;
    DefDevOutInfo: PPaDeviceInfo;
    DefDevOutAPIInfo: PPaHostApiInfo;
    DefDevIn: PaDeviceIndex;
    DefDevInInfo: PPaDeviceInfo;
    DefDevInAPIInfo: PPaHostApiInfo;
    function loadlib: integer;
    procedure unloadlib;
    procedure unloadlibCust(PortAudio : boolean; SndFile: boolean; Mpg123: boolean; SoundTouch: boolean);

    function InitLib: integer;
  end;

type
  Tuos_DeviceInfos = record
    DeviceNum: shortint;
    DeviceName: string;
    DeviceType: string;
    DefaultDevIn: boolean;
    DefaultDevOut: boolean;
    ChannelsIn: integer;
    ChannelsOut: integer;
    SampleRate: CDouble;
    LatencyHighIn: CDouble;
    LatencyLowIn: CDouble;
    LatencyHighOut: CDouble;
    LatencyLowOut: CDouble;
    HostAPIName: string;
  end;

type
  Tuos_WaveHeaderChunk = packed record
    wFormatTag: smallint;
    wChannels: word;
    wSamplesPerSec: cardinal;
    wAvgBytesPerSec: cardinal;
    wBlockAlign: word;
    wBitsPerSample: word;
    wcbSize: word;
  end;

type
  Tuos_FileBuffer = record
    ERROR: word;
    wSamplesPerSec: cardinal;
    wBitsPerSample: word;
    wChannels: word;
    Data: TMemoryStream;
  end;

type
  Tuos_Data = record  /////////////// common data
    Enabled: boolean;
    TypePut: shortint;
    ////// -1 : nothing,  //// for Input : 0:from audio file, 1:from input device, 2:from other stream
    //// for Output : 0:into wav file, 1:into output device, 2:to other stream
    Seekable: boolean;
    Status: shortint;
    Buffer: TDArFloat;
    DSPVolumeInIndex : cardinal;
    DSPVolumeOutIndex : cardinal;
    VLeft, VRight: double;
    levelEnable : boolean;
    LevelLeft, LevelRight: double;
     {$if defined(cpu64)}
    Wantframes: Tsf_count_t;
    OutFrames: Tsf_count_t;
    {$else}
    Wantframes: longint;
    OutFrames: longint;
    {$endif}
    SamplerateRoot: longword;
    SampleRate: longword;
    SampleFormat: shortint;
    Channels: integer;
    /////////// audio file data
    HandleSt: pointer;
    Filename: string;
    Title: string;
    Copyright: string;
    Software: string;
    Artist: string;
    Comment: string;
    Date: string;
    Tag: array[0..2] of char;
    Album: string;
    Genre: byte;
    HDFormat: integer;
    Frames: Tsf_count_t;
    Sections: integer;
    Encoding: integer;
    Lengthst: integer;     ///////  in sample ;
    LibOpen: shortint;    //// -1 : nothing open, 0 : sndfile open, 1 : mpg123 open
    Ratio: shortint;      ////  if mpg123 then ratio := 2
    Position: longint;
    Poseek: longint;
    Output: integer;
    PAParam: PaStreamParameters;
    FileBuffer: Tuos_FileBuffer;
  end;

type
  Tuos_FFT = class(TObject)
  public
    TypeFilter: shortint;
    LowFrequency, HighFrequency: integer;
    AlsoBuf: boolean;
    a3, a32: array[0..2] of cfloat;
    b2, x0, x1, y0, y1, b22, x02, x12, y02, y12: array[0..1] of cfloat;
    C, D, C2, D2, Gain, LeftResult, RightResult: cfloat;
  end;

type
  TFunc = function(Data: Tuos_Data; FFT: Tuos_FFT): TDArFloat;
  TProc = procedure of object;
  TPlugFunc = function(bufferin: TDArFloat; plugHandle: THandle; NumProceed : Integer;
    param1: float; param2: float; param3: float; param4: float;
    param5: float; param6: float): TDArFloat;

type
  Tuos_DSP = class(TObject)
  public
    Enabled: boolean;
    BefProc: TFunc;     //// function to execute before buffer is filled
    AftProc: TFunc;     //// function to execute after buffer is filled
    LoopProc: TProc;     //// External Procedure after buffer is filled
    ////////////// for FFT
    fftdata: Tuos_FFT;
    destructor Destroy; override;
  end;

type
  Tuos_InStream = class(TObject)
  public
    Data: Tuos_Data;
    DSP: array of Tuos_DSP;
    LoopProc: procedure of object;    //// external procedure to execute in loop
    destructor Destroy; override;
  end;

type
  Tuos_OutStream = class(TObject)
  public
    Data: Tuos_Data;
    DSP: array of Tuos_DSP;
    LoopProc: procedure of object;    //// external procedure to execute in loop
    destructor Destroy; override;
  end;

  Tuos_Plugin = class(TObject)
  public
    Enabled: boolean;
    Name: string;
    PlugHandle: THandle;
    PlugFunc: TPlugFunc;
    param1: float;
    param2: float;
    param3: float;
    param4: float;
    param5: float;
    param6: float;
    Buffer: TDArFloat;
  end;

type
   Tuos_Player = class(TThread)
  protected
    evPause: PRTLEvent;  // for pausing
    procedure Execute; override;
    procedure onTerminate;
  public
    isAssigned: boolean ;
    Status: shortint;
    Index: cardinal;
    BeginProc: procedure of object;
    //// external procedure to execute at begin of thread

    EndProc: procedure of object;
    //// procedure to execute at end of thread

    StreamIn: array of Tuos_InStream;
    StreamOut: array of Tuos_OutStream;
    PlugIn: array of Tuos_Plugin;

     {$IF (FPC_FULLVERSION >= 20701) or DEFINED(LCL) or DEFINED(Windows) or DEFINED(ConsoleApp) or DEFINED(Library)}
      constructor Create(CreateSuspended: boolean;
      const StackSize: SizeUInt = DefaultStackSize);
     {$else}
      Refer: TObject;  //// for fpGUI
      constructor Create(CreateSuspended: boolean; AParent: TObject;
      const StackSize: SizeUInt = DefaultStackSize);     //// for fpGUI
    {$endif}

    destructor Destroy; override;

    /////////////////////Audio procedure
    Procedure Play() ;        ///// Start playing

    procedure RePlay();                ///// Resume playing after pause

    procedure Stop();                  ///// Stop playing and free thread

    procedure Pause();                 ///// Pause playing

    function AddIntoDevOut(Device: integer; Latency: CDouble;
      SampleRate: integer; Channels: integer; SampleFormat: shortint ; FramesCount: integer ): integer;
     ////// Add a Output into Device Output
    //////////// Device ( -1 is default device )
    //////////// Latency  ( -1 is latency suggested ) )
    //////////// SampleRate : delault : -1 (44100)
    //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
    //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
    //////////// FramesCount : default : -1 (= 65536)
    //  result :  Output Index in array    -1 = error
    /// example : OutputIndex1 := AddOutput(-1,-1,-1,-1,0);

    function AddIntoFile(Filename: string; SampleRate: integer;
      Channels: integer; SampleFormat: shortint ; FramesCount: integer): integer;
    /////// Add a Output into audio wav file with custom parameters
     ////////// FileName : filename of saved audio wav file
    //////////// SampleRate : delault : -1 (44100)
    //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
    //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
    //////////// FramesCount : default : -1 (= 65536)
    //  result : Output Index in array     -1 = error
    //////////// example : OutputIndex1 := AddIntoFile(edit5.Text,-1,-1, 0, -1);

    function AddFromDevIn(Device: integer; Latency: CDouble;
  SampleRate: integer; Channels: integer; OutputIndex: cardinal;
  SampleFormat: shortint; FramesCount : integer): integer;
   ////// Add a Input from Device Input with custom parameters
    //////////// Device ( -1 is default Input device )
    //////////// Latency  ( -1 is latency suggested ) )
    //////////// SampleRate : delault : -1 (44100)
    //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
    //////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
    //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
    //////////// FramesCount : default : -1 (65536)
    //  result :  otherwise Output Index in array   -1 = error
    /// example : OutputIndex1 := AddFromDevice(-1,-1,-1,-1,-1,-1);

    function AddFromFile(Filename: string; OutputIndex: cardinal;
      SampleFormat: shortint ; FramesCount: integer): integer;
    /////// Add a input from audio file with custom parameters
    ////////// FileName : filename of audio file
    ////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
    //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
    //////////// FramesCount : default : -1 (65536)
    //  result :   Input Index in array    -1 = error
    //////////// example : InputIndex1 := AddFromFile(edit5.Text,-1,0,-1);

    function AddPlugin(PlugName: string; SampleRate: integer;
      Channels: integer): cardinal;
    /////// Add a plugin , result is PluginIndex
    //////////// SampleRate : delault : -1 (44100)
    //////////// Channels : delault : -1 (2:stereo) (1:mono, 2:stereo, ...)
    ////// Till now, only 'soundtouch' PlugName is registred.

    procedure SetPluginSoundTouch(PluginIndex: cardinal; Tempo: cfloat;
      Pitch: cfloat; Enable: boolean);
    ////////// PluginIndex : PluginIndex Index of a existing Plugin.
    //////////                proc : loopprocedure

    function GetStatus() : integer ;
    /////// Get the status of the player : 0 => has stopped, 1 => is running, 2 => is paused, -1 => error.

    procedure Seek(InputIndex: cardinal; pos: Tsf_count_t);
    //// change position in sample

    procedure SeekSeconds(InputIndex: cardinal; pos: cfloat);
    //// change position in seconds

    procedure SeekTime(InputIndex: cardinal; pos: TTime);
    //// change position in time format

    function InputLength(InputIndex: cardinal): longint;
    ////////// InputIndex : InputIndex of existing input
    ///////  result : Length of Input in samples

    function InputLengthSeconds(InputIndex: cardinal): cfloat;
    ////////// InputIndex : InputIndex of existing input
    ///////  result : Length of Input in seconds

    function InputLengthTime(InputIndex: cardinal): TTime;
    ////////// InputIndex : InputIndex of existing input
    ///////  result : Length of Input in time format

    function InputPosition(InputIndex: cardinal): longint;
    ////////// InputIndex : InputIndex of existing input
    ////// result : current postion in sample

    function InputGetLevelLeft(InputIndex: cardinal): double;
    ////////// InputIndex : InputIndex of existing input
    ////// result : left level from 0 to 1

    function InputGetLevelRight(InputIndex: cardinal): double;
    ////////// InputIndex : InputIndex of existing input
    ////// result : right level from 0 to 1

    function InputPositionSeconds(InputIndex: cardinal): cfloat;
    ////////// InputIndex : InputIndex of existing input
    ///////  result : current postion of Input in seconds

    function InputPositionTime(InputIndex: cardinal): TTime;
    ////////// InputIndex : InputIndex of existing input
    ///////  result : current postion of Input in time format

    function AddDSPin(InputIndex: cardinal; BeforeProc: TFunc;
      AfterProc: TFunc; LoopProc: TProc): cardinal;
    ///// add a DSP procedure for input
    ////////// InputIndex : Input Index of a existing input
    ////////// BeforeProc : procedure to do before the buffer is filled
    ////////// AfterProc : procedure to do after the buffer is filled
    ////////// LoopProc : external procedure to do after the buffer is filled
    //  result :  index of DSPin in array  (DSPinIndex)
    ////////// example : DSPinIndex1 := AddDSPIn(InputIndex1,@beforereverse,@afterreverse,nil);

    procedure SetDSPin(InputIndex: cardinal; DSPinIndex: cardinal; Enable: boolean);
    ////////// InputIndex : Input Index of a existing input
    ////////// DSPIndexIn : DSP Index of a existing DSP In
    ////////// Enable :  DSP enabled
    ////////// example : SetDSPIn(InputIndex1,DSPinIndex1,True);

    function AddDSPout(OutputIndex: cardinal; BeforeProc: TFunc;
      AfterProc: TFunc; LoopProc: TProc): cardinal;    //// usefull if multi output
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// BeforeProc : procedure to do before the buffer is filled
    ////////// AfterProc : procedure to do after the buffer is filled just before to give to output
    ////////// LoopProc : external procedure to do after the buffer is filled
    //  result : index of DSPout in array
    ////////// example :DSPoutIndex1 := AddDSPout(OutputIndex1,@volumeproc,nil,nil);

    procedure SetDSPout(OutputIndex: cardinal; DSPoutIndex: cardinal; Enable: boolean);
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// DSPoutIndex : DSPoutIndex of existing DSPout
    ////////// Enable :  DSP enabled
    ////////// example : SetDSPIn(OutputIndex1,DSPoutIndex1,True);

    function AddFilterIn(InputIndex: cardinal; LowFrequency: integer;
      HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
      AlsoBuf: boolean; LoopProc: TProc): cardinal;
    ////////// InputIndex : InputIndex of a existing Input
    ////////// LowFrequency : Lowest frequency of filter
    ////////// HighFrequency : Highest frequency of filter
    ////////// Gain : gain to apply to filter
    ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
    /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
    ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
    ////////// LoopProc : External procedure to execute after DSP done
    //  result :  otherwise index of DSPIn in array
    ////////// example :FilterInIndex1 := AddFilterIn(InputIndex1,6000,16000,1,2,true,nil);

    procedure SetFilterIn(InputIndex: cardinal; FilterIndex: cardinal;
      LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
      TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
    ////////// InputIndex : InputIndex of a existing Input
    ////////// DSPInIndex : DSPInIndex of existing DSPIn
    ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
    ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
    ////////// Gain : gain to apply to filter
    ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
    /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
    ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
    ////////// LoopProc : External procedure to execute after DSP done
    ////////// Enable :  Filter enabled
    ////////// example : SetFilterIn(InputIndex1,FilterInIndex1,-1,-1,-1,False,True,nil);

    function AddFilterOut(OutputIndex: cardinal; LowFrequency: integer;
      HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
      AlsoBuf: boolean; LoopProc: TProc): cardinal;
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// LowFrequency : Lowest frequency of filter
    ////////// HighFrequency : Highest frequency of filter
    ////////// Gain : gain to apply to filter
    ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
    /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
    ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
    ////////// LoopProc : External procedure to execute after DSP done
    //  result : index of DSPOut in array
    ////////// example :FilterOutIndex1 := AddFilterOut(OutputIndex1,6000,16000,1,true,nil);

    procedure SetFilterOut(OutputIndex: cardinal; FilterIndex: cardinal;
      LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
      TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// FilterIndex : DSPOutIndex of existing DSPOut
    ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
    ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
    ////////// Gain : gain to apply to filter
    ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
    /// fBandPass = 3, fHighPass = 4, fLowPass = 5)
    ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
    ////////// Enable :  Filter enabled
    ////////// LoopProc : External procedure to execute after DSP done
    ////////// example : SetFilterOut(OutputIndex1,FilterOutIndex1,1000,1500,-1,True,True,nil);

    function DSPLevel(Data: Tuos_Data): Tuos_Data;
    //////////// to get level of buffer (volume)

    function AddDSPVolumeIn(InputIndex: cardinal; VolLeft: double;
      VolRight: double): cardinal;
    ///// DSP Volume changer
    ////////// InputIndex : InputIndex of a existing Input
    ////////// VolLeft : Left volume
    ////////// VolRight : Right volume
    //  result :  index of DSPIn in array
    ////////// example  DSPIndex1 := AddDSPVolumeIn(InputIndex1,1,1);

    function AddDSPVolumeOut(OutputIndex: cardinal; VolLeft: double;
      VolRight: double): cardinal;
    ///// DSP Volume changer
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// VolLeft : Left volume
    ////////// VolRight : Right volume
    //  result :  otherwise index of DSPIn in array
    ////////// example  DSPIndex1 := AddDSPVolumeIn(InputIndex1,1,1);

    procedure SetDSPVolumeIn(InputIndex: cardinal; DSPVolIndex: cardinal;
      VolLeft: double; VolRight: double; Enable: boolean);
    ////////// InputIndex : InputIndex of a existing Input
    ////////// DSPIndex : DSPIndex of a existing DSP
    ////////// VolLeft : Left volume
    ////////// VolRight : Right volume
    ////////// Enable : Enabled
    ////////// example  SetDSPVolumeIn(InputIndex1,DSPIndex1,1,0.8,True);

    procedure SetDSPVolumeOut(OutputIndex: cardinal; DSPVolIndex: cardinal;
      VolLeft: double; VolRight: double; Enable: boolean);
    ////////// OutputIndex : OutputIndex of a existing Output
    ////////// DSPIndex : DSPIndex of a existing DSP
    ////////// VolLeft : Left volume
    ////////// VolRight : Right volume
    ////////// Enable : Enabled
    ////////// example  SetDSPVolumeOut(InputIndex1,DSPIndex1,1,0.8,True);

   end;

//////////// General public procedure/function (accessible for library uos too)

procedure uos_GetInfoDevice();

function uos_GetInfoDeviceStr() : String ;

function uos_loadlib(PortAudioFileName: String; SndFileFileName: String; Mpg123FileName: String; SoundTouchFileName: String) : integer;
        ////// load libraries... if libraryfilename = '' =>  do not load it...  You may load what and when you want...

procedure uos_unloadlib();
        ////// Unload all libraries... Do not forget to call it before close application...

procedure uos_unloadlibCust(PortAudio : boolean; SndFile: boolean; Mpg123: boolean; SoundTouch: boolean);
           ////// Custom Unload libraries... if true, then delete the library. You may unload what and when you want...

{$IF (FPC_FULLVERSION >= 20701) or  DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Windows) or DEFINED(Library)}
procedure uos_CreatePlayer(PlayerIndex: cardinal);
{$else}
procedure uos_CreatePlayer(PlayerIndex: cardinal; AParent: TObject);
{$endif}
        //// PlayerIndex : from 0 to what your computer can do ! (depends of ram, cpu, soundcard, ...)
        //// If PlayerIndex already exists, it will be overwriten...

function uos_AddIntoDevOut(PlayerIndex: Cardinal; Device: integer; Latency: CDouble;
            SampleRate: integer; Channels: integer; SampleFormat: shortint ; FramesCount: integer ): integer;
          ////// Add a Output into Device Output with custom parameters
function uos_AddIntoDevOut(PlayerIndex: Cardinal): integer;
          ////// Add a Output into Device Output with default parameters
          //////////// PlayerIndex : Index of a existing Player
          //////////// Device ( -1 is default device )
          //////////// Latency  ( -1 is latency suggested ) )
          //////////// SampleRate : delault : -1 (44100)
          //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
          //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
          //////////// FramesCount : default : -1 (= 65536)
          //  result : Output Index in array  , -1 = error
          /// example : OutputIndex1 := uos_AddIntoDevOut(0,-1,-1,-1,-1,0);

function uos_AddFromFile(PlayerIndex: Cardinal; Filename: string; OutputIndex: Cardinal;
              SampleFormat: shortint ; FramesCount: integer): integer;
            /////// Add a input from audio file with custom parameters
function uos_AddFromFile(PlayerIndex: Cardinal; Filename: string): integer;
            /////// Add a input from audio file with default parameters
            //////////// PlayerIndex : Index of a existing Player
            ////////// FileName : filename of audio file
            ////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
            //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
            //////////// FramesCount : default : -1 (65536)
            //  result : Input Index in array  -1 = error
            //////////// example : InputIndex1 := uos_AddFromFile(0, edit5.Text,-1,0);

function uos_AddIntoFile(PlayerIndex: Cardinal; Filename: string; SampleRate: integer;
                 Channels: integer; SampleFormat: shortint ; FramesCount: integer): integer;
               /////// Add a Output into audio wav file with custom parameters
               //////////// PlayerIndex : Index of a existing Player
               ////////// FileName : filename of saved audio wav file
               //////////// SampleRate : delault : -1 (44100)
               //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
               //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
               //////////// FramesCount : default : -1 (= 65536)
               //  result :Output Index in array  -1 = error
               //////////// example : OutputIndex1 := uos_AddIntoFile(0,edit5.Text,-1,-1, 0, -1);
function uos_AddIntoFile(PlayerIndex: Cardinal; Filename: String): integer;
               /////// Add a Output into audio wav file with Default parameters
              //////////// PlayerIndex : Index of a existing Player
              ////////// FileName : filename of saved audio wav file

function uos_AddFromDevIn(PlayerIndex: Cardinal; Device: integer; Latency: CDouble;
             SampleRate: integer; Channels: integer; OutputIndex: integer;
             SampleFormat: shortint; FramesCount : integer): integer;
              ////// Add a Input from Device Input with custom parameters
              //////////// PlayerIndex : Index of a existing Player
               //////////// Device ( -1 is default Input device )
               //////////// Latency  ( -1 is latency suggested ) )
               //////////// SampleRate : delault : -1 (44100)
               //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
               //////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
               //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
               //////////// FramesCount : default : -1 (65536)
               //  result :  Output Index in array
               /// example : OutputIndex1 := uos_AddFromDevIn(-1,-1,-1,-1,-1,-1);
function uos_AddFromDevIn(PlayerIndex: Cardinal): integer;
              ////// Add a Input from Device Input with custom parameters
              ///////// PlayerIndex : Index of a existing Player

procedure uos_BeginProc(PlayerIndex: Cardinal; Proc: TProc);
            ///// Assign the procedure of object to execute  at begining, before loop
            //////////// PlayerIndex : Index of a existing Player
            //////////// InIndex : Index of a existing Input

procedure uos_EndProc(PlayerIndex: Cardinal; Proc: TProc);
            ///// Assign the procedure of object to execute  at end, after loop
            //////////// PlayerIndex : Index of a existing Player
            //////////// InIndex : Index of a existing Input


procedure uos_LoopProcIn(PlayerIndex: Cardinal; InIndex: Cardinal; Proc: TProc);
            ///// Assign the procedure of object to execute inside the loop
            //////////// PlayerIndex : Index of a existing Player
            //////////// InIndex : Index of a existing Input

procedure uos_LoopProcOut(PlayerIndex: Cardinal; OutIndex: Cardinal; Proc: TProc);
              ///// Assign the procedure of object to execute inside the loop
            //////////// PlayerIndex : Index of a existing Player
            //////////// OutIndex : Index of a existing Output

procedure uos_AddDSPVolumeIn(PlayerIndex: Cardinal; InputIndex: Cardinal; VolLeft: double;
                 VolRight: double) ;
               ///// DSP Volume changer
               //////////// PlayerIndex : Index of a existing Player
               ////////// InputIndex : InputIndex of a existing Input
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               ////////// example  uos_AddDSPVolumeIn(0,InputIndex1,1,1);

procedure uos_AddDSPVolumeOut(PlayerIndex: Cardinal; OutputIndex: Cardinal; VolLeft: double;
                 VolRight: double) ;
               ///// DSP Volume changer
               //////////// PlayerIndex : Index of a existing Player
               ////////// OutputIndex : OutputIndex of a existing Output
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               //  result : -1 nothing created, otherwise index of DSPIn in array
               ////////// example  DSPIndex1 := uos_AddDSPVolumeOut(o,oututIndex1,1,1);

procedure uos_SetDSPVolumeIn(PlayerIndex: Cardinal; InputIndex: Cardinal;
                 VolLeft: double; VolRight: double; Enable: boolean);
               ////////// InputIndex : InputIndex of a existing Input
               //////////// PlayerIndex : Index of a existing Player
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               ////////// Enable : Enabled
               ////////// example  uos_SetDSPVolumeIn(0,InputIndex1,DSPIndex1,1,0.8,True);

procedure uos_SetDSPVolumeOut(PlayerIndex: Cardinal; OutputIndex: Cardinal;
                 VolLeft: double; VolRight: double; Enable: boolean);
               ////////// OutputIndex : OutputIndex of a existing Output
               //////////// PlayerIndex : Index of a existing Player
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               ////////// Enable : Enabled
               ////////// example  uos_SetDSPVolumeOut(0,outputIndex1,DSPIndex1,1,0.8,True);

function uos_AddDSPin(PlayerIndex: Cardinal; InputIndex: cardinal; BeforeProc: TFunc;
                    AfterProc: TFunc; LoopProc: TProc): integer;
                  ///// add a DSP procedure for input
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : Input Index of a existing input
                  ////////// BeforeProc : procedure to do before the buffer is filled
                  ////////// AfterProc : procedure to do after the buffer is filled
                  ////////// LoopProc : external procedure to do after the buffer is filled
                  //  result : -1 nothing created, otherwise index of DSPin in array  (DSPinIndex)
                  ////////// example : DSPinIndex1 := uos_AddDSPin(0,InputIndex1,@beforereverse,@afterreverse,nil);

procedure uos_SetDSPin(PlayerIndex: Cardinal; InputIndex: cardinal; DSPinIndex: cardinal; Enable: boolean);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : Input Index of a existing input
                  ////////// DSPIndexIn : DSP Index of a existing DSP In
                  ////////// Enable :  DSP enabled
                  ////////// example : uos_SetDSPin(0,InputIndex1,DSPinIndex1,True);

function uos_AddDSPout(PlayerIndex: Cardinal; OutputIndex: cardinal; BeforeProc: TFunc;
                    AfterProc: TFunc; LoopProc: TProc): integer;    //// usefull if multi output
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// BeforeProc : procedure to do before the buffer is filled
                  ////////// AfterProc : procedure to do after the buffer is filled just before to give to output
                  ////////// LoopProc : external procedure to do after the buffer is filled
                  //  result : index of DSPout in array
                  ////////// example :DSPoutIndex1 := uos_AddDSPout(0,OutputIndex1,@volumeproc,nil,nil);

procedure uos_SetDSPout(PlayerIndex: Cardinal; OutputIndex: cardinal; DSPoutIndex: cardinal; Enable: boolean);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// DSPoutIndex : DSPoutIndex of existing DSPout
                  ////////// Enable :  DSP enabled
                  ////////// example : uos_SetDSPout(0,OutputIndex1,DSPoutIndex1,True);

function uos_AddFilterIn(PlayerIndex: Cardinal; InputIndex: cardinal; LowFrequency: integer;
                    HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
                    AlsoBuf: boolean; LoopProc: TProc): integer ;
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : InputIndex of a existing Input
                  ////////// LowFrequency : Lowest frequency of filter
                  ////////// HighFrequency : Highest frequency of filter
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  //  result : index of DSPIn in array   -1 = error
                  ////////// example :FilterInIndex1 := uos_AddFilterIn(0,InputIndex1,6000,16000,1,2,true,nil);

procedure uos_SetFilterIn(PlayerIndex: Cardinal; InputIndex: cardinal; FilterIndex: Cardinal;
                    LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
                    TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : InputIndex of a existing Input
                  ////////// DSPInIndex : DSPInIndex of existing DSPIn
                  ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
                  ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  ////////// Enable :  Filter enabled
                  ////////// example : uos_SetFilterIn(0,InputIndex1,FilterInIndex1,-1,-1,-1,False,True,nil);

function uos_AddFilterOut(PlayerIndex: Cardinal; OutputIndex: cardinal; LowFrequency: integer;
                    HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
                    AlsoBuf: boolean; LoopProc: TProc): integer;
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// LowFrequency : Lowest frequency of filter
                  ////////// HighFrequency : Highest frequency of filter
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  //  result : index of DSPOut in array  -1 = error
                  ////////// example :FilterOutIndex1 := uos_AddFilterOut(0,OutputIndex1,6000,16000,1,true,nil);

procedure uos_SetFilterOut(PlayerIndex: Cardinal; OutputIndex: cardinal; FilterIndex: Cardinal;
                    LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
                    TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// FilterIndex : DSPOutIndex of existing DSPOut
                  ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
                  ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// Enable :  Filter enabled
                  ////////// LoopProc : External procedure to execute after DSP done
                  ////////// example : uos_SetFilterOut(0,OutputIndex1,FilterOutIndex1,1000,1500,-1,True,True,nil);

function uos_AddPlugin(PlayerIndex: Cardinal; PlugName: string; SampleRate: integer;
                       Channels: integer): integer ;
                     /////// Add a plugin , result is PluginIndex
                     //////////// PlayerIndex : Index of a existing Player
                     //////////// SampleRate : delault : -1 (44100)
                     //////////// Channels : delault : -1 (2:stereo) (1:mono, 2:stereo, ...)
                     ////// Till now, only 'soundtouch' PlugName is registred.

procedure uos_SetPluginSoundTouch(PlayerIndex: Cardinal; PluginIndex: cardinal; Tempo: cfloat;
                       Pitch: cfloat; Enable: boolean);
                     ////////// PluginIndex : PluginIndex Index of a existing Plugin.
                     //////////// PlayerIndex : Index of a existing Player

function uos_GetStatus(PlayerIndex: Cardinal) : integer ;
             /////// Get the status of the player : -1 => error,  0 => has stopped, 1 => is running, 2 => is paused.

procedure uos_Seek(PlayerIndex: Cardinal; InputIndex: cardinal; pos: Tsf_count_t);
                     //// change position in sample

procedure uos_SeekSeconds(PlayerIndex: Cardinal; InputIndex: cardinal; pos: cfloat);
                     //// change position in seconds

procedure uos_SeekTime(PlayerIndex: Cardinal; InputIndex: cardinal; pos: TTime);
                     //// change position in time format

function uos_InputLength(PlayerIndex: Cardinal; InputIndex: cardinal): longint;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in samples

function uos_InputLengthSeconds(PlayerIndex: Cardinal; InputIndex: cardinal): cfloat;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in seconds

function uos_InputLengthTime(PlayerIndex: Cardinal; InputIndex: cardinal): TTime;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in time format

function uos_InputPosition(PlayerIndex: Cardinal; InputIndex: cardinal): longint;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : current postion in sample

procedure uos_InputSetLevelEnable(PlayerIndex: Cardinal; InputIndex: cardinal ; enable : boolean);
                   ///////// enable/disable level(volume) calculation (default is false/disable)

function uos_InputGetLevelLeft(PlayerIndex: Cardinal; InputIndex: cardinal): double;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : left level(volume) from 0 to 1

function uos_InputGetLevelRight(PlayerIndex: Cardinal; InputIndex: cardinal): double;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : right level(volume) from 0 to 1

function uos_InputPositionSeconds(PlayerIndex: Cardinal; InputIndex: cardinal): cfloat;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : current postion of Input in seconds

function uos_InputPositionTime(PlayerIndex: Cardinal; InputIndex: cardinal): TTime;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : current postion of Input in time format

function uos_InputGetSampleRate(PlayerIndex: Cardinal; InputIndex: cardinal): integer;
                   ////////// InputIndex : InputIndex of existing input
                  ////// result : default sample rate


procedure uos_Play(PlayerIndex: Cardinal) ;        ///// Start playing

procedure uos_RePlay(PlayerIndex: Cardinal);                ///// Resume playing after pause

procedure uos_Stop(PlayerIndex: Cardinal);                  ///// Stop playing and free thread

procedure uos_Pause(PlayerIndex: Cardinal);                 ///// Pause playing

const
  ///// error
  noError = 0;
  FilePAError = 10;
  LoadPAError = 11;
  FileSFError = 20;
  LoadSFError = 21;
  FileMPError = 30;
  LoadMPError = 31;
  ///// uos Audio
  Stereo = 2;
  Mono = 1;
  DefRate = 44100;
  ////////////// Write wav file
  ReadError = 1;
  HeaderError = 2;
  DataError = 3;
  FileCorrupt = 4;
  IncorectFileFormat = 5;
  HeaderWriteError = 6;
  StreamError = 7;
  /////////////////// FFT Filters
  fBandAll = 0;
  fBandSelect = 1;
  fBandReject = 2;
  fBandPass = 3;
  fHighPass = 4;
  fLowPass = 5;
   {$IF (FPC_FULLVERSION >= 20701) or DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
     {$else}
  MSG_CUSTOM1 = FPGM_USER + 1;
    {$endif}

var
  uosPlayers: array of Tuos_Player;
  uosPlayersStat : array of shortint;
  uosDeviceInfos: array of Tuos_DeviceInfos;
  uosLoadResult: Tuos_LoadResult;
  uosDeviceCount: integer;
  uosDefaultDeviceIn: integer;
  uosDefaultDeviceOut: integer;
  uosInit: Tuos_Init;
  old8087cw: word;


implementation

function FormatBuf(Inbuf: TDArFloat; format: shortint): TDArFloat;
var
  x: integer;
  ps: PDArShort;     //////// if input is Int16 format
  pl: PDArLong;      //////// if input is Int32 format
  pf: PDArFloat;     //////// if input is Float32 format
begin

  case format of
    2:
    begin
      ps := @inbuf;
      for x := 0 to high(inbuf) do
        ps^[x] := cint16(round(ps^[x]));
    end;
    1:
    begin
      pl := @inbuf;
      for x := 0 to high(inbuf) do
        pl^[x] := cint32(round(pl^[x]));
    end;
    0:
    begin
      pf := @inbuf;
      for x := 0 to high(inbuf) do
        pf^[x] := cfloat(pf^[x]);
    end;
  end;
  Result := Inbuf;
end;

function CvFloat32ToInt16(Inbuf: TDArFloat): TDArShort;
var
  x, i: integer;
  arsh: TDArShort;
begin
  SetLength(arsh, length(inbuf));
  for x := 0 to high(Inbuf) do
  begin
    i := round(Inbuf[x] * 32768);
    if i > 32767 then
      i := 32767
    else
    if i < -32768 then
      i := -32768;
    arsh[x] := i;
  end;
  Result := arsh;
end;

function CvFloat32ToInt32(Inbuf: TDArFloat): TDArLong;
var
   i: int64;
   x : cardinal;
  arlo: TDArLong;
begin
  SetLength(arlo, length(inbuf));
  for x := 0 to high(Inbuf) do
  begin
    i := round(Inbuf[x] * 2147483647);
    if i > 2147483647 then
      i := 2147483647
    else
    if i < -2147483648 then
      i := -2147483648;
    arlo[x] := i;
  end;
  Result := arlo;
end;

function CvInt16ToFloat32(Inbuf: TDArFloat): TDArFloat;
var
  x: integer;
  arfl: TDArFloat;
  ps: PDArShort;
begin
    setlength(arfl,length(Inbuf));
  ps := @inbuf;
  for x := 0 to high(Inbuf) do
    arfl[x] := ps^[x] / 32768;
  Result := arfl;
end;

function CvInt32ToFloat32(Inbuf: TDArFloat): TDArFloat;
var
  x: integer;
  arfl: TDArFloat;
  pl: PDArLong;
begin
   setlength(arfl,length(Inbuf));
  pl := @inbuf;
  for x := 0 to high(Inbuf) do
    arfl[x] := pl^[x] / 2147483647;
  Result := arfl;
end;

function WriteWave(FileName: ansistring; Data: Tuos_FileBuffer): word;
var
  f: TFileStream;
  wFileSize: cardinal;
  wChunkSize: cardinal;
  ID: array[0..3] of char;
  Header: Tuos_WaveHeaderChunk;
begin
  Result := noError;
  f := nil;
  try
    f := TFileStream.Create(FileName, fmCreate);
    f.Seek(0, soFromBeginning);
    ID := 'RIFF';
    f.WriteBuffer(ID, 4);
    wFileSize := 0;
    f.WriteBuffer(wFileSize, 4);
    ID := 'WAVE';
    f.WriteBuffer(ID, 4);
    ID := 'fmt ';
    f.WriteBuffer(ID, 4);
    wChunkSize := SizeOf(Header);
    f.WriteBuffer(wChunkSize, 4);
    Header.wFormatTag := 1;
    Header.wChannels := Data.wChannels;
    Header.wSamplesPerSec := Data.wSamplesPerSec;
    Header.wBlockAlign := Data.wChannels * (Data.wBitsPerSample div 8);
    Header.wAvgBytesPerSec := Data.wSamplesPerSec * Header.wBlockAlign;
    Header.wBitsPerSample := Data.wBitsPerSample;
    Header.wcbSize := 0;
    f.WriteBuffer(Header, SizeOf(Header));
  except
    Result := HeaderWriteError;
  end;
  try
    ID := 'data';
    f.WriteBuffer(ID, 4);
    wChunkSize := Data.Data.Size;
    f.WriteBuffer(wChunkSize, 4);
    Data.Data.Seek(0, soFromBeginning);
    f.CopyFrom(Data.Data, Data.Data.Size);
  except
    Result := StreamError;
  end;
  f.Seek(SizeOf(ID), soFromBeginning);
  wFileSize := f.Size - SizeOf(ID) - SizeOf(wFileSize);
  f.Write(wFileSize, 4);
  f.Free;
end;

function Tuos_Player.GetStatus() : integer ;
    /////// Get the status of the player : -1 => error, 0 => has stopped, 1 => is running, 2 => is paused.
begin
   if (isAssigned = True) then  result := Status else result := -1 ;
end;

procedure Tuos_Player.Play() ;
var
  x: integer;
  err: shortint;
begin
  if (isAssigned = True) then
  begin
  err := -1;

  for x := 0 to high(StreamOut) do
    if StreamOut[x].Data.HandleSt <> nil then
    begin
      err := Pa_StartStream(StreamOut[x].Data.HandleSt);
     end;

  for x := 0 to high(StreamIn) do
    if (StreamIn[x].Data.HandleSt <> nil) and (StreamIn[x].Data.TypePut = 1) then
    begin
      err := Pa_StartStream(StreamIn[x].Data.HandleSt);
      sleep(200);
     end;

  start;   // resume;  //  { if fpc version <= 2.4.4}
  Status := 1;
  RTLeventSetEvent(evPause);
end;

end;

procedure Tuos_Player.RePlay();   /////// Resume Playing after Pause
begin

  if  (Status > 0) and (isAssigned = True) then
  begin
    Status := 1;
    RTLeventSetEvent(evPause);
  end;
end;

procedure Tuos_Player.Stop();
begin
  if (Status > 0) and (isAssigned = True) then
  begin
    RTLeventSetEvent(evPause);
    Status := 0;
  end;
end;

procedure Tuos_Player.Pause();
begin
  if (Status > 0) and (isAssigned = True) then
  begin
    RTLeventResetEvent(evPause);
    Status := 2;
  end;
end;

procedure Tuos_Player.Seek(InputIndex:cardinal; pos: Tsf_count_t);
//// change position in samples
begin
   if (isAssigned = True) then StreamIn[InputIndex].Data.Poseek := pos;
end;

procedure Tuos_Player.SeekSeconds(InputIndex: cardinal; pos: cfloat);
//// change position in seconds
begin
    if  (isAssigned = True) then  StreamIn[InputIndex].Data.Poseek :=
      trunc(pos * StreamIn[InputIndex].Data.SampleRate);
end;

procedure Tuos_Player.SeekTime(InputIndex: cardinal; pos: TTime);
//// change position in time format
var
  ho, mi, se, ms, possample: word;
begin
    if (isAssigned = True) then begin
  DecodeTime(pos, ho, mi, se, ms);

  possample := trunc(((ho * 3600) + (mi * 60) + se + (ms / 1000)) *
    StreamIn[InputIndex].Data.SampleRate);

   StreamIn[InputIndex].Data.Poseek := possample;
     end;
end;

function Tuos_Player.InputLength(InputIndex: cardinal): longint;
  //// gives length in samples
begin
   if (isAssigned = True) then Result := StreamIn[InputIndex].Data.Lengthst;
end;

function Tuos_Player.InputLengthSeconds(InputIndex: cardinal): cfloat;
begin
    if  (isAssigned = True) then Result := StreamIn[InputIndex].Data.Lengthst / StreamIn[InputIndex].Data.SampleRate;
end;

function Tuos_Player.InputLengthTime(InputIndex: cardinal): TTime;
var
  tmp: cfloat;
  h, m, s, ms: word;
begin

   if (Status > 0) and (isAssigned = True) then tmp := InputLengthSeconds(InputIndex);
    ms := trunc(frac(tmp) * 1000);
    h := trunc(tmp / 3600);
    m := trunc(tmp / 60 - h * 60);
    s := trunc(tmp - (h * 3600 + m * 60));
    Result := EncodeTime(h, m, s, ms);
end;

function Tuos_Player.InputPosition(InputIndex: cardinal): longint;
  //// gives current position
begin
   if (isAssigned = True) then Result := StreamIn[InputIndex].Data.Position;
end;

function Tuos_Player.InputGetLevelLeft(InputIndex: cardinal): double;
  ////////// InputIndex : InputIndex of existing input
  ////// result : left level(volume) from 0 to 1
begin
   if (Status > 0) and (isAssigned = True) then Result := StreamIn[InputIndex].Data.LevelLeft;
end;

function Tuos_Player.InputGetLevelRight(InputIndex: cardinal): double;
  ////////// InputIndex : InputIndex of existing input
  ////// result : right level(volume) from 0 to 1
begin
   if (isAssigned = True) then Result := StreamIn[InputIndex].Data.LevelRight;
end;

function Tuos_Player.InputPositionSeconds(InputIndex: cardinal): cfloat;
begin
   if (isAssigned = True) then Result := StreamIn[InputIndex].Data.Position / StreamIn[InputIndex].Data.SampleRate;
end;

function Tuos_Player.InputPositionTime(InputIndex: cardinal): TTime;
var
  tmp: cfloat;
  h, m, s, ms: word;
begin
   if (Status > 0) and (isAssigned = True) then tmp := InputPositionSeconds(InputIndex);
    ms := trunc(frac(tmp) * 1000);
    h := trunc(tmp / 3600);
    m := trunc(tmp / 60 - h * 60);
    s := trunc(tmp - (h * 3600 + m * 60));
    Result := EncodeTime(h, m, s, ms);
end;

procedure Tuos_Player.SetDSPin(InputIndex: cardinal; DSPinIndex: cardinal;
  Enable: boolean);
begin
 StreamIn[InputIndex].DSP[DSPinIndex].Enabled := Enable;
end;

procedure Tuos_Player.SetDSPOut(OutputIndex: cardinal; DSPoutIndex: cardinal;
  Enable: boolean);
begin
 StreamOut[OutputIndex].DSP[DSPoutIndex].Enabled := Enable;
end;

function Tuos_Player.AddDSPin(InputIndex: cardinal; BeforeProc: TFunc;
  AfterProc: TFunc; LoopProc: Tproc): cardinal;
begin
    SetLength(StreamIn[InputIndex].DSP, Length(StreamIn[InputIndex].DSP) + 1);
    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1] := Tuos_DSP.Create();
    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1].BefProc := BeforeProc;
    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1].AftProc := AfterProc;
    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1].LoopProc := LoopProc;
    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1].Enabled := True;

    StreamIn[InputIndex].DSP[Length(StreamIn[InputIndex].DSP) - 1].fftdata :=
      Tuos_FFT.Create();

    Result := Length(StreamIn[InputIndex].DSP) - 1;
 end;

function Tuos_Player.AddDSPout(OutputIndex: cardinal; BeforeProc: TFunc;
  AfterProc: TFunc; LoopProc: Tproc): cardinal;
begin
    SetLength(StreamOut[OutputIndex].DSP, Length(StreamOut[OutputIndex].DSP) + 1);
    StreamOut[OutputIndex].DSP[Length(StreamOut[OutputIndex].DSP) - 1] :=
      Tuos_DSP.Create;
    StreamOut[OutputIndex].DSP[Length(StreamOut[OutputIndex].DSP) - 1].BefProc :=
      BeforeProc;
    StreamOut[OutputIndex].DSP[Length(StreamOut[OutputIndex].DSP) - 1].AftProc :=
      AfterProc;
    StreamOut[OutputIndex].DSP[Length(StreamOut[OutputIndex].DSP) - 1].LoopProc :=
      LoopProc;
    StreamOut[OutputIndex].DSP[Length(StreamOut[OutputIndex].DSP) - 1].Enabled := True;
    Result := Length(StreamOut[OutputIndex].DSP) - 1;
 end;

procedure Tuos_Player.SetFilterIn(InputIndex: cardinal; FilterIndex: cardinal;
  LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
  TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
////////// InputIndex : InputIndex of a existing Input
////////// DSPInIndex : DSPInIndex of existing DSPIn
////////// LowFrequency : Lowest frequency of filter ( default = -1 : current LowFrequency )
////////// HighFrequency : Highest frequency of filter ( default = -1 : current HighFrequency )
////////// Gain   : Gain to apply ( -1 = current gain)  ( 0 = silence, 1 = no gain, < 1 = less gain, > 1 = more gain)
////////// TypeFilter: Type of filter : ( default = -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
/////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
////////// LoopProc : External procedure to execute after filter
////////// Enable :  Filter enabled
////////// example : SetFilterIn(InputIndex1,FilterInIndex1,1000,1500,-1,True,nil);
begin
if isAssigned = true then
begin
  StreamIn[InputIndex].DSP[FilterIndex].fftdata.AlsoBuf := AlsoBuf;
  if LowFrequency = -1 then
    LowFrequency := StreamIn[InputIndex].DSP[FilterIndex].fftdata.LowFrequency;
  if HighFrequency = -1 then
    HighFrequency := StreamIn[InputIndex].DSP[FilterIndex].fftdata.HighFrequency;
  StreamIn[InputIndex].DSP[FilterIndex].Enabled := Enable;
  if Gain <> -1 then
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.Gain := cfloat(Gain);

  if TypeFilter <> -1 then
  begin
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.typefilter := TypeFilter;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.C := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.D := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.C2 := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.D2 := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[0] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[1] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[2] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.b22[0] := 0.0;
    StreamIn[InputIndex].DSP[FilterIndex].fftdata.b22[1] := 0.0;

    case TypeFilter of
      1:  /////////////////// DSPFFTBandSelect := DSPFFTBandReject + DSPFFTBandPass
      begin
        //////////////////////   DSPFFTBandReject
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C :=
          Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.D :=
          2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] :=
          1 / (1 + StreamIn[InputIndex].DSP[FilterIndex].fftdata.C);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.D *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] :=
          (1 - StreamIn[InputIndex].DSP[FilterIndex].fftdata.C) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        /////////////////////  DSPFFTBandPass
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C2 :=
          1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.D2 :=
          2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[0] :=
          1 / (1 + StreamIn[InputIndex].DSP[FilterIndex].fftdata.C2);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[1] := 0.0;
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[2] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b22[0] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.C2 *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.D2 *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b22[1] :=
          (StreamIn[InputIndex].DSP[FilterIndex].fftdata.C2 - 1) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a32[0];
        //////////////////
      end;

      2:  ///////////////////  DSPFFTBandReject
      begin
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C :=
          Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.D :=
          2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] :=
          1 / (1 + StreamIn[InputIndex].DSP[FilterIndex].fftdata.C);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.D *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] :=
          (1 - StreamIn[InputIndex].DSP[FilterIndex].fftdata.C) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
      end;

      3:    /////////////////////  DSPFFTBandPass
      begin
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C :=
          1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.D :=
          2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] :=
          1 / (1 + StreamIn[InputIndex].DSP[FilterIndex].fftdata.C);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] := 0.0;
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] :=
          -StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.D *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] :=
          (StreamIn[InputIndex].DSP[FilterIndex].fftdata.C - 1) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
      end;

      4:    /////////////////////  DSPFFTLowPass
      begin
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C :=
          1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] :=
          1 / (1 + Sqrt(2) * StreamIn[InputIndex].DSP[FilterIndex].fftdata.C +
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] :=
          2 * StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] :=
          2 * (1 - StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] :=
          (1 - Sqrt(2) * StreamIn[InputIndex].DSP[FilterIndex].fftdata.C +
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
      end;

      5:    /////////////////////  DSPFFTHighPass
      begin
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.C :=
          Tan(Pi * (HighFrequency - LowFrequency + 1) /
          StreamIn[InputIndex].Data.SampleRate);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0] :=
          1 / (1 + Sqrt(2) * StreamIn[InputIndex].DSP[FilterIndex].fftdata.C +
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C);
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[1] :=
          -2 * StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[2] :=
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[0] :=
          2 * (StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C - 1) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
        StreamIn[InputIndex].DSP[FilterIndex].fftdata.b2[1] :=
          (1 - Sqrt(2) * StreamIn[InputIndex].DSP[FilterIndex].fftdata.C +
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.C) *
          StreamIn[InputIndex].DSP[FilterIndex].fftdata.a3[0];
      end;
    end;
  end;
end;

end;

procedure Tuos_Player.SetFilterOut(OutputIndex: cardinal; FilterIndex: cardinal;
  LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
  TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
////////// OutputIndex : OutputIndex of a existing Output
////////// FilterIndex : DSPOutIndex of existing DSPOut
////////// LowFrequency : Lowest frequency of filter
////////// HighFrequency : Highest frequency of filter
////////// TypeFilter: Type of filter : default = -1 = actual filter (fBandAll = 0, fBandSelect = 1, fBandReject = 2
/////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
////////// Enable :  Filter enabled
////////// LoopProc : External procedure to execute after filter
////////// example : SetFilterOut(OutputIndex1,FilterOutIndex1,1000,1500,-1,True,nil);
begin
if isAssigned = true then
begin
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.AlsoBuf := AlsoBuf;
  StreamOut[OutputIndex].DSP[FilterIndex].Enabled := Enable;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.Gain := cfloat(Gain);
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.typefilter := TypeFilter;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C2 := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D2 := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[0] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[1] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[2] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b22[0] := 0.0;
  StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b22[1] := 0.0;

  case TypeFilter of
    1:  /////////////////// DSPFFTBandSelect := DSPFFTBandReject + DSPFFTBandPass
    begin
      //////////////////////   DSPFFTBandReject
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C :=
        Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D :=
        2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] :=
        1 / (1 + StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] :=
        (1 - StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      /////////////////////  DSPFFTBandPass
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C2 :=
        1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D2 :=
        2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[0] :=
        1 / (1 + StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C2);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[1] := 0.0;
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[2] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b22[0] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C2 *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D2 *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b22[1] :=
        (StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C2 - 1) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a32[0];
      //////////////////
    end;

    2:  ///////////////////  DSPFFTBandReject
    begin
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C :=
        Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D :=
        2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] :=
        1 / (1 + StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] :=
        (1 - StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
    end;

    3:    /////////////////////  DSPFFTBandPass
    begin
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C :=
        1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D :=
        2 * Cos(2 * Pi * ((HighFrequency + LowFrequency) shr 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] :=
        1 / (1 + StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] := 0.0;
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] :=
        -StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.D *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] :=
        (StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C - 1) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
    end;

    4:    /////////////////////  DSPFFTLowPass
    begin
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C :=
        1 / Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] :=
        1 / (1 + Sqrt(2) * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C +
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] :=
        2 * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] :=
        2 * (1 - StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] :=
        (1 - Sqrt(2) * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C +
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
    end;

    5:    /////////////////////  DSPFFTHighPass
    begin
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C :=
        Tan(Pi * (HighFrequency - LowFrequency + 1) /
        StreamOut[OutputIndex].Data.SampleRate);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0] :=
        1 / (1 + Sqrt(2) * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C +
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C);
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[1] :=
        -2 * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[2] :=
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[0] :=
        2 * (StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C - 1) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
      StreamOut[OutputIndex].DSP[FilterIndex].fftdata.b2[1] :=
        (1 - Sqrt(2) * StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C +
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.C) *
        StreamOut[OutputIndex].DSP[FilterIndex].fftdata.a3[0];
    end;
  end;
end;

end;

function SoundTouchPlug(bufferin: TDArFloat; plugHandle: THandle; NumSample : Integer;
  tempo: float; pitch: float; channels: float; ratio: float; notused1: float;
  notused2: float): TDArFloat;
var
  numoutbuf, x1, x2: integer;
  BufferplugFLTMP: TDArFloat;
  BufferplugFL: TDArFloat;
begin
  soundtouch_putSamples(plugHandle, pointer(bufferin),
    length(bufferin) div round(Channels * ratio));

  numoutbuf := 1;
  SetLength(BufferplugFL, 0);

   SetLength(BufferplugFLTMP, length(bufferin));

  if NumSample > 0 then
    while numoutbuf > 0 do
    begin
      numoutbuf := soundtouch_receiveSamples(PlugHandle,
        pointer(BufferplugFLTMP), NumSample);
      SetLength(BufferplugFL, length(BufferplugFL) + round(numoutbuf * Channels));
      x2 := Length(BufferplugFL) - round(numoutbuf * Channels);

      for x1 := 0 to round(numoutbuf * Channels) - 1 do
      begin
        BufferplugFL[x1 + x2] := BufferplugFLTMP[x1];
      end;
    end;
  Result := BufferplugFL;
end;

function Tuos_Player.AddPlugin(PlugName: string; SampleRate: integer;
  Channels: integer): cardinal;
  //////////// SampleRate : delault : -1 (44100)
  //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
  //////////// Result is PluginIndex
var
  x: integer;
begin
   if lowercase(PlugName) = 'soundtouch' then
  begin /// till now only 'soundtouch' is registered
    SetLength(Plugin, Length(Plugin) + 1);
    Plugin[Length(Plugin) - 1] := Tuos_Plugin.Create();
    x := Length(Plugin) - 1;
    Plugin[x].Name := lowercase(PlugName);
    Plugin[x].Enabled := True;
    Plugin[x].param1 := -1;
    Plugin[x].param2 := -1;
    Plugin[x].param3 := -1;
    Plugin[x].param4 := -1;
    Plugin[x].param5 := -1;
    Plugin[x].param6 := -1;
    Plugin[x].PlugHandle := soundtouch_createInstance();
    if SampleRate = -1 then
      soundtouch_setSampleRate(Plugin[x].PlugHandle, 44100)
    else
      soundtouch_setSampleRate(Plugin[x].PlugHandle, SampleRate);
    if Channels = -1 then
      soundtouch_setChannels(Plugin[x].PlugHandle, 2)
    else
      soundtouch_setChannels(Plugin[x].PlugHandle, Channels);
    soundtouch_setRate(Plugin[x].PlugHandle, 1);
    soundtouch_setTempo(Plugin[x].PlugHandle, 1);
    soundtouch_clear(Plugin[x].PlugHandle);
    Plugin[x].PlugFunc := @soundtouchplug;
    Result := x;
  end;
end;

procedure Tuos_Player.SetPluginSoundTouch(PluginIndex: cardinal;
  Tempo: cfloat; Pitch: cfloat; Enable: boolean);
begin
  soundtouch_setRate(Plugin[PluginIndex].PlugHandle, Pitch);
  soundtouch_setTempo(Plugin[PluginIndex].PlugHandle, Tempo);
  Plugin[PluginIndex].Enabled := Enable;
  Plugin[PluginIndex].param1 := Tempo;
  Plugin[PluginIndex].param2 := Pitch;
end;

function uos_DSPVolume(Data: Tuos_Data; fft: Tuos_FFT): TDArFloat;
var
  x, ratio: integer;
  vleft, vright: double;
  ps: PDArShort;     //////// if input is Int16 format
  pl: PDArLong;      //////// if input is Int32 format
  pf: PDArFloat;     //////// if input is Float32 format
begin

  vleft := Data.VLeft;
  vright := Data.VRight;

  case Data.SampleFormat of
    2:
    begin
      ps := @Data.Buffer;
      for x := 0 to (Data.OutFrames) do
        if odd(x) then
          ps^[x] := trunc(ps^[x] * vright)
        else
          ps^[x] := trunc(ps^[x] * vleft);
    end;
    1:
    begin
      pl := @Data.Buffer;
      for x := 0 to (Data.OutFrames) do
        if odd(x) then
          pl^[x] := trunc(pl^[x] * vright)
        else
          pl^[x] := trunc(pl^[x] * vleft);
    end;
    0:
    begin
      case Data.LibOpen of
        0: ratio := 1;
        1: ratio := 2;
      end;
      pf := @Data.Buffer;
      for x := 0 to (Data.OutFrames div ratio) do
        if odd(x) then
          pf^[x] := pf^[x] * vright
        else
          pf^[x] := pf^[x] * vleft;
    end;
  end;
  Result := Data.Buffer;
end;

function Tuos_Player.DSPLevel(Data: Tuos_Data): Tuos_Data;
var
  x, ratio: integer;
  ps: PDArShort;     //////// if input is Int16 format
  pl: PDArLong;      //////// if input is Int32 format
  pf: PDArFloat;     //////// if input is Float32 format
  mins, maxs: array[0..1] of cInt16;    //////// if input is Int16 format
  minl, maxl: array[0..1] of cInt32;    //////// if input is Int32 format
  minf, maxf: array[0..1] of cfloat;    //////// if input is Float32 format
begin

  case Data.SampleFormat of
    2:
    begin
      mins[0] := 32767;
      mins[1] := 32767;
      maxs[0] := -32768;
      maxs[1] := -32768;
      ps := @Data.Buffer;
      x := 0;
      while x < Data.OutFrames do
      begin
        if ps^[x] < mins[0] then
          mins[0] := ps^[x];
        if ps^[x] > maxs[0] then
          maxs[0] := ps^[x];

        Inc(x, 1);

        if ps^[x] < mins[1] then
          mins[1] := ps^[x];
        if ps^[x] > maxs[1] then
          maxs[1] := ps^[x];

        Inc(x, 1);
      end;

      if Abs(mins[0]) > Abs(maxs[0]) then
        Data.LevelLeft := Sqrt(Abs(mins[0]) / 32768)
      else
        Data.LevelLeft := Sqrt(Abs(maxs[0]) / 32768);

      if Abs(mins[1]) > Abs(maxs[1]) then
        Data.Levelright := Sqrt(Abs(mins[1]) / 32768)
      else
        Data.Levelright := Sqrt(Abs(maxs[1]) / 32768);

    end;

    1:
    begin
      minl[0] := 2147483647;
      minl[1] := 2147483647;
      maxl[0] := -2147483648;
      maxl[1] := -2147483648;
      pl := @Data.Buffer;
      x := 0;
      while x < Data.OutFrames do
      begin
        if pl^[x] < minl[0] then
          minl[0] := pl^[x];
        if pl^[x] > maxl[0] then
          maxl[0] := pl^[x];

        Inc(x, 1);

        if pl^[x] < minl[1] then
          minl[1] := pl^[x];
        if pl^[x] > maxl[1] then
          maxl[1] := pl^[x];

        Inc(x, 1);
      end;

      if Abs(minl[0]) > Abs(maxl[0]) then
        Data.LevelLeft := Sqrt(Abs(minl[0]) / 2147483648)
      else
        Data.LevelLeft := Sqrt(Abs(maxl[0]) / 2147483648);

      if Abs(minl[1]) > Abs(maxl[1]) then
        Data.Levelright := Sqrt(Abs(minl[1]) / 2147483648)
      else
        Data.Levelright := Sqrt(Abs(maxl[1]) / 2147483648);
    end;

    0:
    begin
      case Data.LibOpen of
        0: ratio := 1;
        1: ratio := 2;
      end;

      minf[0] := 1;
      minf[1] := 1;
      maxf[0] := -1;
      maxf[1] := -1;
      pf := @Data.Buffer;
      x := 0;
      while x < (Data.OutFrames div ratio) do
      begin
        if pf^[x] < minf[0] then
          minf[0] := pf^[x];
        if pf^[x] > maxf[0] then
          maxf[0] := pf^[x];

        Inc(x, 1);

        if pf^[x] < minf[1] then
          minf[1] := pf^[x];
        if pf^[x] > maxf[1] then
          maxf[1] := pf^[x];

        Inc(x, 1);
      end;

      if Abs(minf[0]) > Abs(maxf[0]) then
        Data.LevelLeft := Sqrt(Abs(minf[0]))
      else
        Data.LevelLeft := Sqrt(Abs(maxf[0]));

      if Abs(minf[1]) > Abs(maxf[1]) then
        Data.Levelright := Sqrt(Abs(minf[1]))
      else
        Data.Levelright := Sqrt(Abs(maxf[1]));
    end;
  end;

  Result := Data;
end;

function uos_BandFilter(Data: Tuos_Data; fft: Tuos_FFT): TDArFloat;
var
  i, ratio: integer;
  ifbuf: boolean;
  arg, res, res2: cfloat;
  ps: PDArShort;     //////// if input is Int16 format
  pl: PDArLong;      //////// if input is Int32 format
  pf: PDArFloat;     //////// if input is Float32 format
begin

  ratio := 1;
  ifbuf := fft.AlsoBuf;

  case Data.SampleFormat of
    2: ps := @Data.Buffer;
    1: pl := @Data.Buffer;
    0:
    begin
      case Data.LibOpen of
        0: ratio := 1;
        1: ratio := 2;
      end;
      pf := @Data.Buffer;
    end;
  end;
  i := 0;
  while i < (Data.OutFrames div ratio) do
  begin

    case Data.SampleFormat of
      2: arg := ps^[i];
      1: arg := pl^[i];
      0: arg := pf^[i];
    end;

    res := fft.a3[0] * arg + fft.a3[1] * fft.x0[0] + fft.a3[2] *
      fft.x1[0] - fft.b2[0] * fft.y0[0] - fft.b2[1] * fft.y1[0];
    if fft.typefilter = 1 then
    begin
      res2 := fft.a32[0] * arg + fft.a32[1] * fft.x02[0] + fft.a32[2] *
        fft.x12[0] - fft.b22[0] * fft.y02[0] - fft.b22[1] * fft.y12[0];

      case Data.SampleFormat of
        2:
        begin
          fft.RightResult := round((res * 1) + (res2 * fft.gain));
          if ifbuf = True then
            ps^[i] := round((res * 1) + (res2 * fft.gain));
        end;
        1:
        begin
          fft.RightResult := round((res * 1) + (res2 * fft.gain));
          if ifbuf = True then
            pl^[i] := round((res * 1) + (res2 * fft.gain));
        end;
        0:
        begin
          fft.RightResult := ((res * 1) + (res2 * fft.gain));
          if ifbuf = True then
            pf^[i] := ((res * 1) + (res2 * fft.gain));
        end;
      end;

    end
    else
      case Data.SampleFormat of
        2:
        begin
          fft.RightResult := round(res * fft.gain);
          if ifbuf = True then
            ps^[i] := round((res * fft.gain));
        end;
        1:
        begin
          fft.RightResult := round((res * fft.gain));
          if ifbuf = True then
            pl^[i] := round((res * fft.gain));
        end;
        0:
        begin
          fft.RightResult := ((res * fft.gain));
          if ifbuf = True then
            pf^[i] := ((res * fft.gain));
        end;
      end;

    fft.x1[0] := fft.x0[0];
    fft.x0[0] := arg;
    fft.y1[0] := fft.y0[0];
    fft.y0[0] := res;

    if fft.typefilter = 1 then
    begin
      fft.x12[0] := fft.x02[0];
      fft.x02[0] := arg;
      fft.y12[0] := fft.y02[0];
      fft.y02[0] := res2;
    end;

    if Data.Channels = 2 then
    begin
      Inc(i);
      case Data.SampleFormat of
        2: arg := ps^[i];
        1: arg := pl^[i];
        0: arg := pf^[i];
      end;
      res := fft.a3[0] * arg + fft.a3[1] * fft.x0[1] + fft.a3[2] *
        fft.x1[1] - fft.b2[0] * fft.y0[1] - fft.b2[1] * fft.y1[1];

      if fft.typefilter = 1 then
      begin
        res2 := fft.a32[0] * arg + fft.a32[1] * fft.x02[1] +
          fft.a32[2] * fft.x12[1] - fft.b22[0] * fft.y02[1] -
          fft.b22[1] * fft.y12[1];

        case Data.SampleFormat of
          2:
          begin
            fft.LeftResult := round((res * 1) + (res2 * fft.gain));
            if ifbuf = True then
              ps^[i] := round((res * 1) + (res2 * fft.gain));
          end;
          1:
          begin
            fft.LeftResult := round((res * 1) + (res2 * fft.gain));
            if ifbuf = True then
              pl^[i] := round((res * 1) + (res2 * fft.gain));
          end;
          0:
          begin
            fft.LeftResult := ((res * 1) + (res2 * fft.gain));
            if ifbuf = True then
              pf^[i] := ((res * 1) + (res2 * fft.gain));
          end;
       end;

      end
      else
        case Data.SampleFormat of
          2:
          begin
            fft.LeftResult := round((res * fft.gain));
            if ifbuf = True then
              ps^[i] := round((res * fft.gain));
          end;
          1:
          begin
            fft.LeftResult := round((res * fft.gain));
            if ifbuf = True then
              pl^[i] := round((res * fft.gain));
          end;
          0:
          begin
            fft.LeftResult := ((res * fft.gain));
            if ifbuf = True then
              pf^[i] := ((res * fft.gain));
          end;
        end;

      fft.x1[1] := fft.x0[1];
      fft.x0[1] := arg;
      fft.y1[1] := fft.y0[1];
      fft.y0[1] := res;

      if fft.typefilter = 1 then
      begin
        fft.x12[1] := fft.x02[1];
        fft.x02[1] := arg;
        fft.y12[1] := fft.y02[1];
        fft.y02[1] := res2;
      end;

    end;
    Inc(i);
  end;

  Result := Data.Buffer;

end;

function Tuos_Player.AddDSPVolumeIn(InputIndex: cardinal; VolLeft: double;
  VolRight: double): cardinal;  ///// DSP Volume changer
  ////////// InputIndex : InputIndex of a existing Input
  ////////// VolLeft : Left volume
  ////////// VolRight : Right volume
  //  result : index of DSPIn in array
  ////////// example  DSPIndex1 := AddDSPVolumeIn(InputIndex1,1,1);
begin
  Result := AddDSPin(InputIndex, nil, @uos_DSPVolume, nil);
  StreamIn[InputIndex].Data.VLeft := VolLeft;
  StreamIn[InputIndex].Data.VRight := VolRight;
end;

function Tuos_Player.AddDSPVolumeOut(OutputIndex: cardinal; VolLeft: double;
  VolRight: double): cardinal;  ///// DSP Volume changer
  ////////// OutputIndex : OutputIndex of a existing Output
  ////////// VolLeft : Left volume ( 1 = max)
  ////////// VolRight : Right volume ( 1 = max)
  //  result :  index of DSPIn in array
  ////////// example  DSPIndex1 := AddDSPVolumeOut(OutputIndex1,1,1);
begin
  Result := AddDSPin(OutputIndex, nil, @uos_DSPVolume, nil);
  StreamOut[OutputIndex].Data.VLeft := VolLeft;
  StreamOut[OutputIndex].Data.VRight := VolRight;
end;

procedure Tuos_Player.SetDSPVolumeIn(InputIndex: cardinal; DSPVolIndex: cardinal;
  VolLeft: double; VolRight: double; Enable: boolean);
////////// InputIndex : InputIndex of a existing Input
////////// DSPIndex : DSPVolIndex of a existing DSPVolume
////////// VolLeft : Left volume ( -1 = do not change)
////////// VolRight : Right volume ( -1 = do not change)
////////// Enable : Enabled
////////// example  SetDSPVolumeIn(InputIndex1,DSPVolIndex1,1,0.8,True);
begin
  if VolLeft <> -1 then
    StreamIn[InputIndex].Data.VLeft := VolLeft;
  if VolRight <> -1 then
    StreamIn[InputIndex].Data.VRight := VolRight;
  StreamIn[InputIndex].DSP[DSPVolIndex].Enabled := Enable;
end;

procedure Tuos_Player.SetDSPVolumeOut(OutputIndex: cardinal;
  DSPVolIndex: cardinal; VolLeft: double; VolRight: double; Enable: boolean);
////////// OutputIndex : OutputIndex of a existing Output
////////// DSPIndex : DSPIndex of a existing DSP
////////// VolLeft : Left volume
////////// VolRight : Right volume
////////// Enable : Enabled
////////// example  SetDSPVolumeOut(InputIndex1,DSPIndex1,1,0.8,True);
begin
  if VolLeft <> -1 then
    StreamOut[OutputIndex].Data.VLeft := VolLeft;
  if VolRight <> -1 then
    StreamOut[OutputIndex].Data.VRight := VolRight;
  StreamOut[OutputIndex].DSP[DSPVolIndex].Enabled := Enable;
end;

procedure uos_AddDSPVolumeIn(PlayerIndex: Cardinal; InputIndex: cardinal; VolLeft: double;
                 VolRight: double);
begin
    if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].StreamIn[InputIndex].Data.DSPVolumeInIndex := uosPlayers[PlayerIndex].AddDSPVolumeIn(InputIndex, VolLeft, VolRight);
end;
               ///// DSP Volume changer
               //////////// PlayerIndex : Index of a existing Player
               ////////// InputIndex : InputIndex of a existing Input
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               //  result : -1 nothing created, otherwise index of DSPIn in array
               ////////// example  DSPIndex1 := AddDSPVolumeIn(0,InputIndex1,1,1);

procedure uos_AddDSPVolumeOut(PlayerIndex: Cardinal; OutputIndex: cardinal; VolLeft: double;
                 VolRight: double);
begin
    if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].StreamOut[OutputIndex].Data.DSPVolumeOutIndex := uosPlayers[PlayerIndex].AddDSPVolumeOut(OutputIndex, VolLeft, VolRight);
end;
               ///// DSP Volume changer
               //////////// PlayerIndex : Index of a existing Player
               ////////// OutputIndex : OutputIndex of a existing Output
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               //  result : -1 nothing created, otherwise index of DSPIn in array
               ////////// example  DSPIndex1 := AddDSPVolumeOut(0,InputIndex1,1,1);

procedure uos_SetDSPVolumeIn(PlayerIndex: Cardinal; InputIndex: cardinal;
                 VolLeft: double; VolRight: double; Enable: boolean);
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].SetDSPVolumeIn(InputIndex,  uosPlayers[PlayerIndex].StreamIn[InputIndex].Data.DSPVolumeInIndex, VolLeft, VolRight, Enable);
end;
               ////////// InputIndex : InputIndex of a existing Input
               //////////// PlayerIndex : Index of a existing Player
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               ////////// Enable : Enabled
               ////////// example  SetDSPVolumeIn(0,InputIndex1,1,0.8,True);

procedure uos_SetDSPVolumeOut(PlayerIndex: Cardinal; OutputIndex: cardinal;
                 VolLeft: double; VolRight: double; Enable: boolean);
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].SetDSPVolumeOut(OutputIndex, uosPlayers[PlayerIndex].StreamOut[OutputIndex].Data.DSPVolumeOutIndex, VolLeft, VolRight, Enable);
end;
               ////////// OutputIndex : OutputIndex of a existing Output
               //////////// PlayerIndex : Index of a existing Player
               ////////// VolLeft : Left volume
               ////////// VolRight : Right volume
               ////////// Enable : Enabled
               ////////// example  SetDSPVolumeOut(0,InputIndex1,1,0.8,True);


function Tuos_Player.AddFilterIn(InputIndex: cardinal; LowFrequency: integer;
  HighFrequency: integer; Gain: cfloat; TypeFilter: integer; AlsoBuf: boolean;
  LoopProc: TProc): cardinal;
  ////////// InputIndex : InputIndex of a existing Input
  ////////// LowFrequency : Lowest frequency of filter
  ////////// HighFrequency : Highest frequency of filter
  ////////// Gain : gain to apply to filter ( 1 = no gain )
  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
  ////////// LoopProc : External procedure to execute after filter
  //  result : index of DSPIn in array
  ////////// example :FilterInIndex1 := AddFilterIn(InputIndex1,6000,16000,1,1,True);
var
  FilterIndex: cardinal;
begin
  FilterIndex := AddDSPin(InputIndex, nil, @uos_BandFilter, LoopProc);
  if TypeFilter = -1 then
    TypeFilter := 1;
  SetFilterIn(InputIndex, FilterIndex, LowFrequency, HighFrequency,
    Gain, TypeFilter, AlsoBuf, True, LoopProc);

  Result := FilterIndex;
end;

function Tuos_Player.AddFilterOut(OutputIndex: cardinal; LowFrequency: integer;
  HighFrequency: integer; Gain: cfloat; TypeFilter: integer; AlsoBuf: boolean;
  LoopProc: TProc): cardinal;
  ////////// OutputIndex : OutputIndex of a existing Output
  ////////// LowFrequency : Lowest frequency of filter
  ////////// HighFrequency : Highest frequency of filter
  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
  //  result :  index of DSPOut in array
  ////////// example :FilterOutIndex1 := AddFilterOut(OutputIndex1,6000,16000,1,true);
var
  FilterIndex: cardinal;
begin
  FilterIndex := AddDSPOut(OutputIndex, nil, @uos_BandFilter, LoopProc);
  if TypeFilter = -1 then
    TypeFilter := 1;
  SetFilterOut(OutputIndex, FilterIndex, LowFrequency, HighFrequency,
    Gain, TypeFilter, AlsoBuf, True, LoopProc);

  Result := FilterIndex;

end;

function uos_AddDSPin(PlayerIndex: Cardinal; InputIndex: cardinal; BeforeProc: TFunc;
                    AfterProc: TFunc; LoopProc: TProc): integer;
                  ///// add a DSP procedure for input
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : Input Index of a existing input
                  ////////// BeforeProc : procedure to do before the buffer is filled
                  ////////// AfterProc : procedure to do after the buffer is filled
                  ////////// LoopProc : external procedure to do after the buffer is filled
                  //  result : index of DSPin in array  (DSPinIndex)
                 ////////// example : DSPinIndex1 := AddDSPIn(0,InputIndex1,@beforereverse,@afterreverse,nil);
begin
 result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
result := uosPlayers[PlayerIndex].AddDSPin(InputIndex, BeforeProc, AfterProc, LoopProc) ;
end;

procedure uos_SetDSPin(PlayerIndex: Cardinal; InputIndex: cardinal; DSPinIndex: cardinal; Enable: boolean);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : Input Index of a existing input
                  ////////// DSPIndexIn : DSP Index of a existing DSP In
                  ////////// Enable :  DSP enabled
                  ////////// example : SetDSPIn(0,InputIndex1,DSPinIndex1,True);
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].SetDSPin(InputIndex, DSPinIndex, Enable) ;
end;

function uos_AddDSPout(PlayerIndex: Cardinal; OutputIndex: cardinal; BeforeProc: TFunc;
                    AfterProc: TFunc; LoopProc: TProc): integer;    //// usefull if multi output
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// BeforeProc : procedure to do before the buffer is filled
                  ////////// AfterProc : procedure to do after the buffer is filled just before to give to output
                  ////////// LoopProc : external procedure to do after the buffer is filled
                  //  result :index of DSPout in array
                  ////////// example :DSPoutIndex1 := AddDSPout(0,OutputIndex1,@volumeproc,nil,nil);
begin
 result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
result := uosPlayers[PlayerIndex].AddDSPout(OutputIndex, BeforeProc, AfterProc, LoopProc) ;
end;

procedure uos_SetDSPout(PlayerIndex: Cardinal; OutputIndex: cardinal; DSPoutIndex: cardinal; Enable: boolean);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// DSPoutIndex : DSPoutIndex of existing DSPout
                  ////////// Enable :  DSP enabled
                  ////////// example : SetDSPIn(0,OutputIndex1,DSPoutIndex1,True);
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].SetDSPout(OutputIndex, DSPoutIndex, Enable) ;
end;

function uos_AddFilterIn(PlayerIndex: Cardinal; InputIndex: cardinal; LowFrequency: integer;
                    HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
                    AlsoBuf: boolean; LoopProc: TProc): integer;
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : InputIndex of a existing Input
                  ////////// LowFrequency : Lowest frequency of filter
                  ////////// HighFrequency : Highest frequency of filter
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  //  result :  index of DSPIn in array    -1 = error
                  ////////// example :FilterInIndex1 := AddFilterIn(0,InputIndex1,6000,16000,1,2,true,nil);
begin
 result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
result := uosPlayers[PlayerIndex].AddFilterIn(InputIndex, LowFrequency, HighFrequency, Gain, TypeFilter,
                    AlsoBuf, LoopProc) ;
end;

procedure uos_SetFilterIn(PlayerIndex: Cardinal; InputIndex: cardinal; FilterIndex: cardinal;
                    LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
                    TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// InputIndex : InputIndex of a existing Input
                  ////////// DSPInIndex : DSPInIndex of existing DSPIn
                  ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
                  ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  ////////// Enable :  Filter enabled
                  ////////// example : SetFilterIn(0,InputIndex1,FilterInIndex1,-1,-1,-1,False,True,nil);
begin
if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].SetFilterIn(InputIndex, FilterIndex, LowFrequency, HighFrequency, Gain,
                    TypeFilter, AlsoBuf, Enable, LoopProc);
end;

function uos_AddFilterOut(PlayerIndex: Cardinal; OutputIndex: cardinal; LowFrequency: integer;
                    HighFrequency: integer; Gain: cfloat; TypeFilter: integer;
                    AlsoBuf: boolean; LoopProc: TProc): integer;
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// LowFrequency : Lowest frequency of filter
                  ////////// HighFrequency : Highest frequency of filter
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : default = -1 = fBandSelect (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /////////////////////////// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// LoopProc : External procedure to execute after DSP done
                  //  result : index of DSPOut in array
                  ////////// example :FilterOutIndex1 := AddFilterOut(0,OutputIndex1,6000,16000,1,true,nil);
begin
 result := -1 ;
if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  if  uosPlayersStat[PlayerIndex] = 1 then
result := uosPlayers[PlayerIndex].AddFilterout(OutputIndex, LowFrequency, HighFrequency, Gain, TypeFilter,
                    AlsoBuf, LoopProc) ;
end;

procedure uos_SetFilterOut(PlayerIndex: Cardinal; OutputIndex: cardinal; FilterIndex: cardinal;
                    LowFrequency: integer; HighFrequency: integer; Gain: cfloat;
                    TypeFilter: integer; AlsoBuf: boolean; Enable: boolean; LoopProc: TProc);
                  //////////// PlayerIndex : Index of a existing Player
                  ////////// OutputIndex : OutputIndex of a existing Output
                  ////////// FilterIndex : DSPOutIndex of existing DSPOut
                  ////////// LowFrequency : Lowest frequency of filter ( -1 : current LowFrequency )
                  ////////// HighFrequency : Highest frequency of filter ( -1 : current HighFrequency )
                  ////////// Gain : gain to apply to filter
                  ////////// TypeFilter: Type of filter : ( -1 = current filter ) (fBandAll = 0, fBandSelect = 1, fBandReject = 2
                  /// fBandPass = 3, fHighPass = 4, fLowPass = 5)
                  ////////// AlsoBuf : The filter alter buffer aswell ( otherwise, only result is filled in fft.data )
                  ////////// Enable :  Filter enabled
                  ////////// LoopProc : External procedure to execute after DSP done
                  ////////// example : SetFilterOut(0,OutputIndex1,FilterOutIndex1,1000,1500,-1,True,True,nil);
begin
if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].SetFilterOut(OutputIndex, FilterIndex, LowFrequency, HighFrequency, Gain,
                    TypeFilter, AlsoBuf, Enable, LoopProc);
end;


function Tuos_Player.AddFromDevIn(Device: integer; Latency: CDouble;
  SampleRate: integer; Channels: integer; OutputIndex: cardinal;
  SampleFormat: shortint; FramesCount : integer): integer;
  /// Add Input from IN device with custom parameters
  //////////// Device ( -1 is default Input device )
  //////////// Latency  ( -1 is latency suggested ) )
  //////////// SampleRate : delault : -1 (44100)
  //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
  //////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
  //////////// SampleFormat : -1 default : Int16 (0: Float32, 1:Int32, 2:Int16)
  //////////// FramesCount : -1 default : 4096
  //////////// example : AddFromDevice(-1,-1,-1,-1,-1);
var
  x, err: integer;
begin
 result := -1 ;
  x := 0;
   err := -1;
  SetLength(StreamIn, Length(StreamIn) + 1);
  StreamIn[Length(StreamIn) - 1] := Tuos_InStream.Create();
  x := Length(StreamIn) - 1;
   StreamIn[x].Data.levelEnable := false;
  StreamIn[x].Data.PAParam.HostApiSpecificStreamInfo := nil;

  if device = -1 then
    StreamIn[x].Data.PAParam.device :=
      Pa_GetDefaultInputDevice()
  else
    StreamIn[x].Data.PAParam.device := cint32(device);

  if SampleRate = -1 then
    StreamIn[x].Data.SampleRate := DefRate
  else
    StreamIn[x].Data.SampleRate := SampleRate;
  StreamIn[x].Data.PAParam.SuggestedLatency := CDouble(0);
  StreamIn[x].Data.PAParam.SampleFormat := paInt16;
  case SampleFormat of
    0: StreamIn[x].Data.PAParam.SampleFormat := paFloat32;
    1: StreamIn[x].Data.PAParam.SampleFormat := paInt32;
    2: StreamIn[x].Data.PAParam.SampleFormat := paInt16;
  end;
  if SampleFormat = -1 then
    StreamIn[x].Data.SampleFormat := CInt32(2)
  else
    StreamIn[x].Data.SampleFormat := CInt32(SampleFormat);
  if Channels = -1 then
    StreamIn[x].Data.PAParam.channelCount := CInt32(2)
  else
    StreamIn[x].Data.PAParam.channelCount := CInt32(Channels);

   StreamIn[x].Data.channels := StreamIn[x].Data.PAParam.channelCount;

    if FramesCount = -1 then  StreamIn[x].Data.Wantframes :=  4096 else
    StreamIn[x].Data.Wantframes := (FramesCount) ;

  SetLength(StreamIn[x].Data.Buffer, StreamIn[x].Data.Wantframes* StreamIn[x].Data.channels);

  StreamIn[x].Data.outframes := length(StreamIn[x].Data.Buffer);
  StreamIn[x].Data.Enabled := True;
  StreamIn[x].Data.Status := 1;
  StreamIn[x].Data.TypePut := 1;
  StreamIn[x].Data.ratio := 2;
  StreamIn[x].Data.Output := OutputIndex;
  StreamIn[x].Data.seekable := False;
  StreamIn[x].Data.LibOpen := 2;
  StreamIn[x].LoopProc := nil;
  err := Pa_OpenStream(@StreamIn[x].Data.HandleSt, @StreamIn[x].Data.PAParam,
    nil, StreamIn[x].Data.SampleRate, (512), paClipOff, nil, nil);

  if err <> 0 then
  else
    Result := x;
end;

function uos_AddFromDevIn(PlayerIndex: Cardinal; Device: integer; Latency: CDouble;
             SampleRate: integer; Channels: integer; OutputIndex: integer;
             SampleFormat: shortint; FramesCount : integer): integer;
              ////// Add a Input from Device Input with custom parameters
              //////////// PlayerIndex : Index of a existing Player
               //////////// Device ( -1 is default Input device )
               //////////// Latency  ( -1 is latency suggested ) )
               //////////// SampleRate : delault : -1 (44100)
               //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
               //////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
               //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
               //////////// FramesCount : default : -1 (65536)
               //  result : Output Index in array , -1 is error
               /// example : OutputIndex1 := AddFromDevice(-1,-1,-1,-1,-1,-1);
begin
  result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result :=  uosPlayers[PlayerIndex].AddFromDevIn(Device, Latency, SampleRate, Channels, OutputIndex,
             SampleFormat, FramesCount) ;
end;

function uos_AddFromDevIn(PlayerIndex: Cardinal): integer;
              ////// Add a Input from Device Input with custom parameters
              ///////// PlayerIndex : Index of a existing Player
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result :=  uosPlayers[PlayerIndex].AddFromDevIn(-1, -1, -1, -1, -1, -1, -1) ;
end;

function Tuos_Player.AddIntoFile(Filename: string; SampleRate: integer;
  Channels: integer; SampleFormat: shortint; FramesCount: integer): integer;
  /////// Add a Output into audio wav file with Custom parameters
  ////////// FileName : filename of saved audio wav file
  //////////// SampleRate : delault : -1 (44100)
  //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
  //////////// SampleFormat : -1 default : Int16 : (0: Float32, 1:Int32, 2:Int16)
  //////////// FramesCount : -1 default : 65536
  //  result :  Output Index in array    -1 = error
  //////////// example : OutputIndex1 := AddIntoFile(edit5.Text,-1,-1,0, -1);
var
  x, err: integer;
begin
  result := -1 ;
  x := 0;
  err := -1;
  SetLength(StreamOut, Length(StreamOut) + 1);
  StreamOut[Length(StreamOut) - 1] := Tuos_OutStream.Create();
  x := Length(StreamOut) - 1;
  StreamOut[x].Data.FileBuffer.ERROR := 0;
  StreamOut[x].Data.Enabled := True;
  StreamOut[x].Data.Filename := filename;
  StreamOut[x].Data.TypePut := 0;
    FillChar(StreamOut[x].Data.FileBuffer, sizeof(StreamOut[x].Data.FileBuffer), 0);
  StreamOut[x].Data.FileBuffer.Data := TMemoryStream.Create;

  result := x;

   if (Channels = -1) then
    StreamOut[x].Data.FileBuffer.wChannels := 2
  else
    StreamOut[x].Data.FileBuffer.wChannels := Channels;
  StreamOut[x].Data.Channels := StreamOut[x].Data.FileBuffer.wChannels;

    if FramesCount = -1 then  StreamOut[x].Data.Wantframes :=  65536 div StreamOut[x].Data.Channels else
  StreamOut[x].Data.Wantframes := FramesCount ;

  SetLength(StreamOut[x].Data.Buffer, StreamOut[x].Data.Wantframes*StreamOut[x].Data.Channels);

    if (SampleFormat = -1) or (SampleFormat = 2) then
  begin
    StreamOut[x].Data.FileBuffer.wBitsPerSample := 16;
    StreamOut[x].Data.SampleFormat := 2;
  end;

  if (SampleFormat = 0) then
  begin
    StreamOut[x].Data.FileBuffer.wBitsPerSample := 32;
    StreamOut[x].Data.SampleFormat := 0;
  end;

  if (SampleFormat = 1) then
  begin
    StreamOut[x].Data.FileBuffer.wBitsPerSample := 32;
    StreamOut[x].Data.SampleFormat := 1;
  end;

  if SampleRate = -1 then
    StreamOut[x].Data.FileBuffer.wSamplesPerSec := 44100
  else
    StreamOut[x].Data.FileBuffer.wSamplesPerSec := samplerate;
  StreamOut[x].Data.Samplerate := StreamOut[x].Data.FileBuffer.wSamplesPerSec;
  StreamOut[x].LoopProc := nil;
end;

function uos_AddIntoFile(PlayerIndex: Cardinal; Filename: string; SampleRate: integer;
                 Channels: integer; SampleFormat: shortint ; FramesCount: integer): integer;
               /////// Add a Output into audio wav file with custom parameters
               //////////// PlayerIndex : Index of a existing Player
               ////////// FileName : filename of saved audio wav file
               //////////// SampleRate : delault : -1 (44100)
               //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
               //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
               //////////// FramesCount : default : -1 (= 65536)
               //  result :  Output Index in array     -1 = error;
               //////////// example : OutputIndex1 := AddIntoFile(0,edit5.Text,-1,-1, 0, -1);
begin
   result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 Result :=  uosPlayers[PlayerIndex].AddIntoFile(Filename, SampleRate, Channels, SampleFormat, FramesCount);
end;

function uos_AddIntoFile(PlayerIndex: Cardinal;  Filename: String): integer;
               /////// Add a Output into audio wav file with Default parameters
              //////////// PlayerIndex : Index of a existing Player
              ////////// FileName : filename of saved audio wav file
 begin
      if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
     if  uosPlayersStat[PlayerIndex] = 1 then
 Result :=  uosPlayers[PlayerIndex].AddIntoFile(Filename, -1, -1, -1, -1);
end;

function Tuos_Player.AddIntoDevOut(Device: integer; Latency: CDouble;
  SampleRate: integer; Channels: integer; SampleFormat: shortint; FramesCount: integer): integer;
  /////// Add a Output into OUT device with Custom parameters
  //////////// Device ( -1 is default device )
  //////////// Latency  ( -1 is latency suggested ) )
  //////////// SampleRate : delault : -1 (44100)
  //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
  //////////// SampleFormat : -1 default : Int16 (0: Float32, 1:Int32, 2:Int16)
  //////////// FramesCount : default : -1 (65536)
  //////////// example : AddOutput(-1,-1,-1,-1,-1,-1);
var
  x, err: integer;
begin
  result := -1 ;
  x := 0;
   err := -1;
  SetLength(StreamOut, Length(StreamOut) + 1);
  StreamOut[Length(StreamOut) - 1] := Tuos_OutStream.Create();
  x := Length(StreamOut) - 1;
  StreamOut[x].Data.PAParam.hostApiSpecificStreamInfo := nil;
  if device = -1 then
    StreamOut[x].Data.PAParam.device := Pa_GetDefaultOutputDevice()
  else
    StreamOut[x].Data.PAParam.device := device;
  if SampleRate = -1 then
    StreamOut[x].Data.SampleRate := DefRate
  else
    StreamOut[x].Data.SampleRate := SampleRate;
  if Latency = -1 then

    StreamOut[x].Data.PAParam.SuggestedLatency :=
      ((Pa_GetDeviceInfo(StreamOut[x].Data.PAParam.device)^.
      defaultHighOutputLatency)) * 1

  else
    StreamOut[x].Data.PAParam.SuggestedLatency := CDouble(Latency);

  StreamOut[x].Data.PAParam.SampleFormat := paInt16;
  case SampleFormat of
    0: StreamOut[x].Data.PAParam.SampleFormat := paFloat32;
    1: StreamOut[x].Data.PAParam.SampleFormat := paInt32;
    2: StreamOut[x].Data.PAParam.SampleFormat := paInt16;
  end;
  StreamOut[x].Data.SampleFormat := SampleFormat;

   if Channels = -1 then
    StreamOut[x].Data.PAParam.channelCount := CInt32(2)
  else
    StreamOut[x].Data.PAParam.channelCount := CInt32(Channels);

   StreamOut[x].Data.Channels := StreamOut[x].Data.PAParam.channelCount;

    if FramesCount = -1 then  StreamOut[x].Data.Wantframes := 65536 div StreamOut[x].Data.Channels else

    StreamOut[x].Data.Wantframes := FramesCount ;

  SetLength(StreamOut[x].Data.Buffer, StreamOut[x].Data.Wantframes*StreamOut[x].Data.Channels);

  StreamOut[x].Data.TypePut := 1;
  StreamOut[x].Data.Wantframes :=
    length(StreamOut[x].Data.Buffer) div StreamOut[x].Data.channels;
  StreamOut[x].Data.Enabled := True;

  err := Pa_OpenStream(@StreamOut[x].Data.HandleSt, nil,
    @StreamOut[x].Data.PAParam, StreamOut[x].Data.SampleRate, 512, paClipOff, nil, nil);
  StreamOut[x].LoopProc := nil;
  if err <> 0 then
  else
    Result := x;
end;

function uos_AddIntoDevOut(PlayerIndex: Cardinal; Device: integer; Latency: CDouble;
            SampleRate: integer; Channels: integer; SampleFormat: shortint ; FramesCount: integer ): integer;
          ////// Add a Output into Device Output with custom parameters
begin
  result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result :=  uosPlayers[PlayerIndex].AddIntoDevOut(Device, Latency, SampleRate, Channels, SampleFormat , FramesCount);
end;
          //////////// PlayerIndex : Index of a existing Player
          //////////// Device ( -1 is default device )
          //////////// Latency  ( -1 is latency suggested ) )
          //////////// SampleRate : delault : -1 (44100)
          //////////// Channels : delault : -1 (2:stereo) (0: no channels, 1:mono, 2:stereo, ...)
          //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
          //////////// FramesCount : default : -1 (= 65536)
          //  result : -1 nothing created, otherwise Output Index in array
          /// example : OutputIndex1 := uos_AddIntoDevOut(0,-1,-1,-1,-1,0,-1);

function uos_AddIntoDevOut(PlayerIndex: Cardinal): integer;
          ////// Add a Output into Device Output with default parameters
begin
  Result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result :=  uosPlayers[PlayerIndex].AddIntoDevOut(-1, -1, -1, -1, -1 ,-1);
end;

function Tuos_Player.AddFromFile(Filename: string; OutputIndex: cardinal;
   SampleFormat: shortint ; FramesCount: integer ): integer;
/////// Add a Input from Audio file with Custom parameters
  ////////// FileName : filename of audio file
  ////////// OutputIndex : OutputIndex of existing Output // -1: all output, -2: no output, other integer : existing Output
  ////////// SampleFormat : -1 default : Int16 (0: Float32, 1:Int32, 2:Int16)
  //////////// FramesCount : default : -1 (65536)
  ////////// example : InputIndex := AddFromFile('/usr/home/test.ogg',-1,-1);
var
  //mh: Tmpg123_handle = nil;
  x, err: integer;
  sfInfo: TSF_INFO;
  mpinfo: Tmpg123_frameinfo;
  mpid3v1: Tmpg123_id3v1;
begin
  result := -1 ;
   if fileexists(filename) then
    begin
    x := 0;
    err := -1;
    SetLength(StreamIn, Length(StreamIn) + 1);
    StreamIn[Length(StreamIn) - 1] := Tuos_InStream.Create;
    x := Length(StreamIn) - 1;
    err := -1;
    StreamIn[x].Data.LibOpen := -1;
    StreamIn[x].Data.levelEnable := false;

     if (uosLoadResult.SFloadERROR = 0) then
    begin
      StreamIn[x].Data.HandleSt := sf_open(FileName, SFM_READ, sfInfo);
      (* try to open the file *)
      if StreamIn[x].Data.HandleSt = nil then
      begin
        StreamIn[x].Data.LibOpen := -1;

      end
      else
      begin
        StreamIn[x].Data.LibOpen := 0;
        StreamIn[x].Data.filename := FileName;
        StreamIn[x].Data.channels := SFinfo.channels;
          if FramesCount = -1 then  StreamIn[x].Data.Wantframes := 65536 div StreamIn[x].Data.Channels  else
       StreamIn[x].Data.Wantframes := FramesCount ;

  SetLength(StreamIn[x].Data.Buffer, StreamIn[x].Data.Wantframes*StreamIn[x].Data.Channels);

        StreamIn[x].Data.hdformat := SFinfo.format;
        StreamIn[x].Data.frames := SFinfo.frames;
        StreamIn[x].Data.samplerate := SFinfo.samplerate;
        StreamIn[x].Data.samplerateroot := SFinfo.samplerate;
        StreamIn[x].Data.sections := SFinfo.sections;
        StreamIn[x].Data.copyright :=
          sf_get_string(StreamIn[x].Data.HandleSt, SF_STR_COPYRIGHT);
        StreamIn[x].Data.software :=
          sf_get_string(StreamIn[x].Data.HandleSt, SF_STR_SOFTWARE);
        StreamIn[x].Data.comment :=
          sf_get_string(StreamIn[x].Data.HandleSt, SF_STR_COMMENT);
        StreamIn[x].Data.date := sf_get_string(StreamIn[x].Data.HandleSt, SF_STR_DATE);
        StreamIn[x].Data.Lengthst := sfInfo.frames;
        StreamIn[x].Data.Enabled := False;
        err := 0;
      end;
    end;
    //////////// mpg123
    if ((StreamIn[x].Data.LibOpen = -1)) and (uosLoadResult.MPloadERROR = 0) then
    begin
      Err := -1;

      StreamIn[x].Data.HandleSt := mpg123_new(nil, Err);

      if Err = 0 then
      begin

        if SampleFormat = -1 then
          StreamIn[x].Data.SampleFormat := 2
        else
          StreamIn[x].Data.SampleFormat := SampleFormat;
        mpg123_format_none(StreamIn[x].Data.HandleSt);
        case StreamIn[x].Data.SampleFormat of
          0: mpg123_format(StreamIn[x].Data.HandleSt, DefRate, Stereo,
              MPG123_ENC_FLOAT_32);
          1: mpg123_format(StreamIn[x].Data.HandleSt, DefRate, Stereo,
              MPG123_ENC_SIGNED_32);
          2: mpg123_format(StreamIn[x].Data.HandleSt, DefRate, Stereo,
              MPG123_ENC_SIGNED_16);
        end;

        Err := mpg123_open(StreamIn[x].Data.HandleSt, PChar(FileName));
      end
      else
      begin
        StreamIn[x].Data.LibOpen := -1;
      end;

      if Err = 0 then
        Err := mpg123_getformat(StreamIn[x].Data.HandleSt,
          StreamIn[x].Data.samplerate, StreamIn[x].Data.channels,
          StreamIn[x].Data.encoding);
      if Err = 0 then
      begin
        mpg123_close(StreamIn[x].Data.HandleSt);
         //// Close handle and reload with forced resolution
        StreamIn[x].Data.HandleSt := nil;
        StreamIn[x].Data.HandleSt := mpg123_new(nil, Err);

        mpg123_format_none(StreamIn[x].Data.HandleSt);
        case StreamIn[x].Data.SampleFormat of
          0: mpg123_format(StreamIn[x].Data.HandleSt, StreamIn[x].Data.samplerate,
              StreamIn[x].Data.channels, StreamIn[x].Data.encoding);
          1: mpg123_format(StreamIn[x].Data.HandleSt, StreamIn[x].Data.samplerate,
              StreamIn[x].Data.channels, StreamIn[x].Data.encoding);
          2: mpg123_format(StreamIn[x].Data.HandleSt, StreamIn[x].Data.samplerate,
              StreamIn[x].Data.channels, StreamIn[x].Data.encoding);
        end;
        mpg123_open(StreamIn[x].Data.HandleSt, (PChar(FileName)));
        mpg123_getformat(StreamIn[x].Data.HandleSt,
          StreamIn[x].Data.samplerate, StreamIn[x].Data.channels,
          StreamIn[x].Data.encoding);
        StreamIn[x].Data.filename := filename;
                     if FramesCount = -1 then  StreamIn[x].Data.Wantframes :=   65536 div StreamIn[x].Data.Channels  else

        StreamIn[x].Data.Wantframes := FramesCount ;
        SetLength(StreamIn[x].Data.Buffer, StreamIn[x].Data.Wantframes*StreamIn[x].Data.Channels);

        mpg123_info(StreamIn[x].Data.HandleSt, MPinfo);
        mpg123_id3(StreamIn[x].Data.HandleSt, @mpid3v1, nil);
        ////////////// to do : add id2v2
        StreamIn[x].Data.title := trim(mpid3v1.title);
        StreamIn[x].Data.artist := mpid3v1.artist;
        StreamIn[x].Data.album := mpid3v1.album;
        StreamIn[x].Data.date := mpid3v1.year;
        StreamIn[x].Data.comment := mpid3v1.comment;
        StreamIn[x].Data.tag := mpid3v1.tag;
        StreamIn[x].Data.genre := mpid3v1.genre;
        StreamIn[x].Data.samplerateroot := MPinfo.rate;
        StreamIn[x].Data.samplerate := MPinfo.rate;
        StreamIn[x].Data.hdformat := MPinfo.layer;
        StreamIn[x].Data.frames := MPinfo.framesize;
        StreamIn[x].Data.lengthst := mpg123_length(StreamIn[x].Data.HandleSt);
        StreamIn[x].Data.LibOpen := 1;
      end
      else
      begin
        StreamIn[x].Data.LibOpen := -1;
       end;
    end;

   if err <> 0 then
    begin
      exit;
    end
    else
    begin
      Result := x;
      StreamIn[x].Data.Output := OutputIndex;
      StreamIn[x].Data.Status := 1;
      StreamIn[x].Data.Enabled := True;
      StreamIn[x].Data.Position := 0;
      StreamIn[x].Data.OutFrames := 0;
      StreamIn[x].Data.Poseek := -1;
      StreamIn[x].Data.TypePut := 0;
      StreamIn[x].Data.seekable := True;
      StreamIn[x].LoopProc := nil;
      if SampleFormat = -1 then
        StreamIn[x].Data.SampleFormat := 2
      else
        StreamIn[x].Data.SampleFormat := SampleFormat;

      case StreamIn[x].Data.LibOpen of
        0:
          StreamIn[x].Data.ratio := StreamIn[x].Data.Channels;
        1:
        begin
          if StreamIn[x].Data.SampleFormat = 2 then
            StreamIn[x].Data.ratio := streamIn[x].Data.Channels
          else
            StreamIn[x].Data.ratio := 2 * streamIn[x].Data.Channels;

          if StreamIn[x].Data.SampleFormat = 0 then
            mpg123_param(StreamIn[x].Data.HandleSt, StreamIn[x].Data.Channels,
              MPG123_FORCE_FLOAT, 0);
        end;
      end;
    end;
  end;
end;

function uos_AddFromFile(PlayerIndex: Cardinal; Filename: string; OutputIndex: cardinal;
              SampleFormat: shortint ; FramesCount: integer): integer;
    /////// Add a input from audio file with custom parameters
    //////////// PlayerIndex : Index of a existing Player
    ////////// FileName : filename of audio file
    ////////// OutputIndex : Output index of used output// -1: all output, -2: no output, other integer refer to a existing OutputIndex  (if multi-output then OutName = name of each output separeted by ';')
    //////////// SampleFormat : default : -1 (1:Int16) (0: Float32, 1:Int32, 2:Int16)
    //////////// FramesCount : default : -1 (65536)
    //  result : Input Index in array    -1 = error
    //////////// example : InputIndex1 := AddFromFile(0, edit5.Text,-1,-1);
begin
  result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
     if  uosPlayersStat[PlayerIndex] = 1 then
  Result := uosPlayers[PlayerIndex].AddFromFile(Filename, OutputIndex, SampleFormat, FramesCount);
end;

function uos_AddFromFile(PlayerIndex: Cardinal; Filename: string): integer;
            /////// Add a input from audio file with default parameters
begin
  result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result := uosPlayers[PlayerIndex].AddFromFile(Filename, -1, -1, -1);
end;

function uos_AddPlugin(PlayerIndex: Cardinal; PlugName: string; SampleRate: integer;
                       Channels: integer): integer;
                     /////// Add a plugin , result is PluginIndex
                     //////////// PlayerIndex : Index of a existing Player
                     //////////// SampleRate : delault : -1 (44100)
                     //////////// Channels : delault : -1 (2:stereo) (1:mono, 2:stereo, ...)
                     ////// Till now, only 'soundtouch' PlugName is registred.
begin
  result := -1 ;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  Result := uosPlayers[PlayerIndex].AddPlugin(PlugName, SampleRate, Channels);
end;

procedure uos_SetPluginSoundTouch(PlayerIndex: Cardinal; PluginIndex: cardinal; Tempo: cfloat;
                       Pitch: cfloat; Enable: boolean);
                     ////////// PluginIndex : PluginIndex Index of a existing Plugin.
                     //////////// PlayerIndex : Index of a existing Player
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 uosPlayers[PlayerIndex].SetPluginSoundTouch(PluginIndex, Tempo, Pitch, Enable);
end;

procedure uos_Seek(PlayerIndex: Cardinal; InputIndex: cardinal; pos: Tsf_count_t);
                     //// change position in sample
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].Seek(InputIndex, pos);
end;

function uos_GetStatus(PlayerIndex: Cardinal) : integer ;
                         /////// Get the status of the player : -1 => error, 0 => has stopped, 1 => is running, 2 => is paused.
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  begin
 if  uosPlayersStat[PlayerIndex] = 1 then
 result :=  uosPlayers[PlayerIndex].Status else result := -1 ;
 end else  result := -1 ;
end;

procedure uos_SeekSeconds(PlayerIndex: Cardinal; InputIndex: cardinal; pos: cfloat);
                     //// change position in seconds
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].SeekSeconds(InputIndex, pos);
end;

procedure uos_SeekTime(PlayerIndex: Cardinal; InputIndex: cardinal; pos: TTime);
                     //// change position in time format
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
  uosPlayers[PlayerIndex].SeekTime(InputIndex, pos);
end;

function uos_InputLength(PlayerIndex: Cardinal; InputIndex: cardinal): longint;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in samples
begin
  result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputLength(InputIndex) ;
end;

function uos_InputLengthSeconds(PlayerIndex: Cardinal; InputIndex: cardinal): cfloat;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in seconds
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputLengthSeconds(InputIndex) ;
end;

function uos_InputLengthTime(PlayerIndex: Cardinal; InputIndex: cardinal): TTime;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : Length of Input in time format
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputLengthTime(InputIndex) ;
end;

function uos_InputPosition(PlayerIndex: Cardinal; InputIndex: cardinal): longint;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : current postion in sample
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputPosition(InputIndex) ;
end;

procedure uos_InputSetLevelEnable(PlayerIndex: Cardinal; InputIndex: cardinal ; enable : boolean);
                   ///////// enable/disable level calculation (default is false/disable)
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 uosPlayers[PlayerIndex].StreamIn[InputIndex].Data.levelEnable:= enable;
end;

function uos_InputGetLevelLeft(PlayerIndex: Cardinal; InputIndex: cardinal): double;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : left level(volume) from 0 to 1
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputGetLevelLeft(InputIndex) ;
end;

function uos_InputGetSampleRate(PlayerIndex: Cardinal; InputIndex: cardinal): integer;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : default sample rate
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) and
  (length(uosPlayers[PlayerIndex].StreamIn) > 0) and (InputIndex +1 <= length(uosPlayers[PlayerIndex].StreamIn))
  then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].StreamIn[InputIndex].Data.SamplerateRoot;
end;

function uos_InputGetLevelRight(PlayerIndex: Cardinal; InputIndex: cardinal): double;
                     ////////// InputIndex : InputIndex of existing input
                     ////// result : right level(volume) from 0 to 1
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputGetLevelRight(InputIndex) ;
end;

function uos_InputPositionSeconds(PlayerIndex: Cardinal; InputIndex: cardinal): cfloat;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : current postion of Input in seconds
begin
   result := 0;
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputPositionSeconds(InputIndex) ;
end;

function uos_InputPositionTime(PlayerIndex: Cardinal; InputIndex: cardinal): TTime;
                     ////////// InputIndex : InputIndex of existing input
                     ///////  result : current postion of Input in time format
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
 result := uosPlayers[PlayerIndex].InputPositionTime(InputIndex) ;
end;

Procedure uos_Play(PlayerIndex: Cardinal) ;        ///// Start playing
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].Play() ;
end;

procedure uos_RePlay(PlayerIndex: Cardinal);                ///// Resume playing after pause
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
  if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].RePlay() ;
end;

procedure uos_Stop(PlayerIndex: Cardinal);                  ///// Stop playing and free thread
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
uosPlayers[PlayerIndex].Stop() ;
end;

procedure uos_Pause(PlayerIndex: Cardinal);                 ///// Pause playing
begin
  if (length(uosPlayers) > 0) and (PlayerIndex +1 <= length(uosPlayers)) then
    if  uosPlayersStat[PlayerIndex] = 1 then
uosPlayers[PlayerIndex].Pause() ;
end;

procedure Tuos_Player.Execute;
/////////////////////// The Loop Procedure ///////////////////////////////
var
  x, x2, x3, x4: integer;
  plugenabled: boolean;
  curpos: cint64;
  err: CInt32;
  BufferplugINFLTMP: TDArFloat;
  BufferplugFL: TDArFloat;
  BufferplugSH: TDArShort;
  BufferplugLO: TDArLong;

     {$IF ( FPC_FULLVERSION>=20701 ) or DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
     {$else}
  msg: TfpgMessageParams;  // for fpgui
    {$endif}

begin
  curpos := 0;
   {$IF not DEFINED(Library)}
      if BeginProc <> nil then
    /////  Execute BeginProc procedure
       {$IF FPC_FULLVERSION>=20701}
     queue(BeginProc);
        {$else}
  {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
     synchronize(BeginProc);
  {$else}    /// for fpGUI
  begin
    msg.user.Param1 := -2 ;  // it is the first proc
    fpgPostMessage(self, refer, MSG_CUSTOM1, msg);
   end;
    {$endif}
    {$endif}
    {$endif}

  repeat
    for x := 0 to high(StreamIn) do
    begin

      RTLeventWaitFor(evPause);  ///// is there a pause waiting ?
      RTLeventSetEvent(evPause);

      if (StreamIn[x].Data.HandleSt <> nil) and (StreamIn[x].Data.Status = 1) and
        (StreamIn[x].Data.Enabled = True) then
      begin

        if (StreamIn[x].Data.Poseek > -1) and (StreamIn[x].Data.Seekable = True) then
        begin                    ////// is there a seek waiting ?
          case StreamIn[x].Data.LibOpen of
            0: sf_seek(StreamIn[x].Data.HandleSt, StreamIn[x].Data.Poseek, SEEK_SET);
            1: mpg123_seek(StreamIn[x].Data.HandleSt, StreamIn[x].Data.Poseek, SEEK_SET);
          end;
          curpos := StreamIn[x].Data.Poseek;
          StreamIn[x].Data.Poseek := -1;
        end;

        if (StreamIn[x].Data.Seekable = True) then
          StreamIn[x].Data.position := curpos;

        //////// DSPin BeforeBuffProc
        if (StreamIn[x].Data.Status = 1) and (length(StreamIn[x].DSP) > 0) then
          for x2 := 0 to high(StreamIn[x].DSP) do
            if (StreamIn[x].DSP[x2].Enabled = True) and
              (StreamIn[x].DSP[x2].BefProc <> nil) then
              StreamIn[x].DSP[x2].BefProc(StreamIn[x].Data, StreamIn[x].DSP[x2].fftdata);
        ///// end DSP BeforeBuffProc

        RTLeventWaitFor(evPause);  ///// is there a pause waiting ?
        RTLeventSetEvent(evPause);

        case StreamIn[x].Data.TypePut of
          0:   ///// it is a input from audio file...
          begin
            case StreamIn[x].Data.LibOpen of
              //////////// Here we are, reading the data and store it in buffer
              0: case StreamIn[x].Data.SampleFormat of
                  0: StreamIn[x].Data.OutFrames :=
                      sf_read_float(StreamIn[x].Data.HandleSt,
                      @StreamIn[x].Data.Buffer[0], StreamIn[x].Data.Wantframes);
                  1: StreamIn[x].Data.OutFrames :=
                      sf_read_int(StreamIn[x].Data.HandleSt,
                      @StreamIn[x].Data.Buffer[0], StreamIn[x].Data.Wantframes);
                  2: StreamIn[x].Data.OutFrames :=
                      sf_read_short(StreamIn[x].Data.HandleSt,
                      @StreamIn[x].Data.Buffer[0], StreamIn[x].Data.Wantframes);
                end;
              1:
              begin
                mpg123_read(StreamIn[x].Data.HandleSt, @StreamIn[x].Data.Buffer[0],
                  StreamIn[x].Data.wantframes, StreamIn[x].Data.outframes);
                StreamIn[x].Data.outframes :=
                  StreamIn[x].Data.outframes div StreamIn[x].Data.Channels;
              end;
            end;

            if StreamIn[x].Data.OutFrames < 10 then
              StreamIn[x].Data.status := 0;  //////// no more data then close the stream
          end;

          1:   /////// for Input from device
          begin
            for x2 := 0 to StreamIn[x].Data.WantFrames do
              StreamIn[x].Data.Buffer[x2] := cfloat(0);      ////// clear input
            err := Pa_ReadStream(StreamIn[x].Data.HandleSt,
              @StreamIn[x].Data.Buffer[0], StreamIn[x].Data.WantFrames);
            StreamIn[x].Data.OutFrames :=
              StreamIn[x].Data.WantFrames * StreamIn[x].Data.Channels;
            //  if err = 0 then StreamIn[x].Data.Status := 1 else StreamIn[x].Data.Status := 0;  /// if you want clean buffer
          end;
        end;

        if (StreamIn[x].Data.LibOpen = 1) and (StreamIn[x].Data.SampleFormat < 2) then

          curpos := curpos + (StreamIn[x].Data.OutFrames div
            (StreamIn[x].Data.Channels * 2))
        //// strange outframes float 32 with Mpg123 ?
        else
          curpos := curpos + (StreamIn[x].Data.OutFrames div
            (StreamIn[x].Data.Channels));

        StreamIn[x].Data.position := curpos; // new position

        x2 := 0;

        //////// DSPin AfterBuffProc
        if (StreamIn[x].Data.Status = 1) and (length(StreamIn[x].DSP) > 0) then
          for x2 := 0 to high(StreamIn[x].DSP) do
            if (StreamIn[x].DSP[x2].Enabled = True) then
            begin

              if (StreamIn[x].DSP[x2].AftProc <> nil) then
                StreamIn[x].Data.Buffer :=
                  StreamIn[x].DSP[x2].AftProc(StreamIn[x].Data,
                  StreamIn[x].DSP[x2].fftdata);

              {$IF not DEFINED(Library)}
              if (StreamIn[x].DSP[x2].LoopProc <> nil) then
            {$IF FPC_FULLVERSION>=20701}
          queue(StreamIn[x].DSP[x2].LoopProc);
        {$else}
  {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
      synchronize(StreamIn[x].DSP[x2].LoopProc);
  {$else}
  begin
    msg.user.Param1 := x2 ;   //// the index of the dsp
    msg.user.Param2 := 0;   ////  it is a In DSP
    fpgPostMessage(self, refer, MSG_CUSTOM1, msg);
   end;
    {$endif}
    {$endif}
     {$endif}
       end;
      end;
    end;

        ///// End DSPin AfterBuffProc

        ///////////// the synchro main loop procedure
         {$IF not DEFINED(Library)}
         if StreamIn[x].LoopProc <> nil then
   {$IF FPC_FULLVERSION>=20701}
          queue(StreamIn[x].LoopProc);
        {$else}
  {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
        synchronize(StreamIn[x].LoopProc);
  {$else}   /// for fpGUI
  begin
    msg.user.Param1 := -1 ;  //// it is the main loop procedure
    msg.user.Param2 := 0 ;////  it is a INput procedure
    fpgPostMessage(self, refer, MSG_CUSTOM1, msg);
   end;
    {$endif}
    {$endif}
    {$endif}

   ////////////////// Seeking if StreamIn is terminated
    if status > 0 then
    begin
      status := 0;
      for x := 0 to high(StreamIn) do
        if (StreamIn[x].Data.HandleSt <> nil) and (StreamIn[x].Data.Status = 1) then
          status := 1;
    end;

    RTLeventWaitFor(evPause);  ///// is there a pause waiting ?
    RTLeventSetEvent(evPause);

    //////////////////////// Give Buffer to Output
    if status = 1 then
    begin
   //// getting the level-volume
  if StreamIn[x].Data.levelEnable = true then StreamIn[x].Data := DSPLevel(StreamIn[x].Data);

    for x := 0 to high(StreamOut) do

      if ((StreamOut[x].Data.TypePut = 1) and (StreamOut[x].Data.HandleSt <> nil) and
        (StreamOut[x].Data.Enabled = True)) or
        ((StreamOut[x].Data.TypePut = 0) and (StreamOut[x].Data.Enabled = True))
      then
      begin
        for x2 := 0 to high(StreamOut[x].Data.Buffer) do
          StreamOut[x].Data.Buffer[x2] := cfloat(0);      ////// clear output

        for x2 := 0 to high(StreamIn) do
          if (StreamIn[x2].Data.HandleSt <> nil) and
            (StreamIn[x2].Data.Enabled = True) and
            ((StreamIn[x2].Data.Output = x) or (StreamIn[x2].Data.Output = -1)) then
            for x3 := 0 to high(StreamIn[x2].Data.Buffer) do
              StreamOut[x].Data.Buffer[x3] :=
                cfloat(StreamOut[x].Data.Buffer[x3]) +
                cfloat(StreamIn[x2].Data.Buffer[x3]);
        //////// copy buffer-in into buffer-out

        //////// DSPOut AfterBuffProc
        if (length(StreamOut[x].DSP) > 0) then
          for x3 := 0 to high(StreamOut[x].DSP) do
            if (StreamOut[x].DSP[x3].Enabled = True) then
            begin
              if (StreamOut[x].DSP[x3].AftProc <> nil) then
                StreamOut[x].Data.Buffer :=
                  StreamOut[x].DSP[x3].AftProc(StreamOut[x].Data,
                  StreamOut[x].DSP[x3].fftdata);

                {$IF not DEFINED(Library)}
        if (StreamOut[x].DSP[x3].LoopProc <> nil) then
            {$IF FPC_FULLVERSION>=20701}
         queue(StreamOut[x].DSP[x3].LoopProc);
        {$else}
  {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
       synchronize(StreamOut[x].DSP[x3].LoopProc);
  {$else}
  begin
    msg.user.Param1 := x3 ;   //// the index of the dsp
    msg.user.Param2 := 1;   //// it is a OUT DSP
    fpgPostMessage(self, refer, MSG_CUSTOM1, msg);
   end;
    {$endif}
    {$endif}
    {$endif}

            end;    ///// end DSPOut AfterBuffProc

        ///// apply plugin (ex: SoundTouch Library)

        plugenabled := False;

        if (length(Plugin) > 0) then
        begin
          for x3 := 0 to high(PlugIn) do
            if Plugin[x3].Enabled = True then
              plugenabled := True;
        end;

        if plugenabled = True then
        begin
          ////// convert buffer if needed
          case StreamOut[x].Data.SampleFormat of
            1: StreamOut[x].Data.Buffer :=
                CvInt32toFloat32(StreamOut[x].Data.Buffer);
            2: StreamOut[x].Data.Buffer :=
                CvInt16toFloat32(StreamOut[x].Data.Buffer);
          end;

          // transfer buffer out to temp
          SetLength(BufferplugINFLTMP, (StreamIn[x2].Data.outframes) *
            StreamIn[x2].Data.Channels);
          for x3 := 0 to length(BufferplugINFLTMP) - 1 do
            BufferplugINFLTMP[x3] := cfloat(StreamOut[x].Data.Buffer[x3]);

          //////////// dealing with input plugin
          for x3 := 0 to high(PlugIn) do
          begin
            if PlugIn[x3].Enabled = True then
            begin
              BufferplugFL := Plugin[x3].PlugFunc(BufferplugINFLTMP,
                Plugin[x3].PlugHandle, StreamIn[x2].Data.outframes, Plugin[x3].param1, Plugin[x3].param2,
                StreamIn[x2].Data.Channels, StreamIn[x2].Data.Ratio, -1, -1);

              if length(plugin) > 1 then
                for x4 := 0 to length(BufferplugFL) - 1 do
                  BufferplugINFLTMP[x4] := cfloat(BufferplugFL[x4]);
            end;

            ///////////////////////////////////////////////////////////////////////////
            ///// give the processed input to output
            if Length(BufferplugFL) > 0 then
            begin

              case StreamOut[x].Data.SampleFormat of
                1:
                begin
                  SetLength(BufferplugLO, length(BufferplugFL));
                  BufferplugLO := CvFloat32ToInt32(BufferplugFL);
                end;
                2:
                begin
                  SetLength(BufferplugSH, length(BufferplugFL));
                  BufferplugSH := CvFloat32ToInt16(BufferplugFL);
                end;
              end;

              case StreamOut[x].Data.TypePut of
                1:     /////// Give to output device
                begin
                  case StreamOut[x].Data.SampleFormat of
                    0:
                    begin
                      err := Pa_WriteStream(StreamOut[x].Data.HandleSt,
                        @BufferplugFL[0], Length(BufferplugFL) div
                        StreamIn[x2].Data.Channels);
                    end;
                    1:
                    begin
                      BufferplugLO := CvFloat32ToInt32(BufferplugFL);
                      err := Pa_WriteStream(StreamOut[x].Data.HandleSt,
                        @BufferplugLO[0], Length(BufferplugLO) div
                        StreamIn[x2].Data.Channels);
                    end;
                    2:
                    begin
                      BufferplugSH := CvFloat32ToInt16(BufferplugFL);
                      err := Pa_WriteStream(StreamOut[x].Data.HandleSt,
                        @BufferplugSH[0], Length(BufferplugSH) div
                        StreamIn[x2].Data.Channels);
                    end;
                  end;
                  // if err <> 0 then status := 0;   // if you want clean buffer ...
                end;

                0:
                begin  /////// Give to wav file
                  BufferplugSH := CvFloat32ToInt16(BufferplugFL);
                  StreamOut[x].Data.FileBuffer.Data.WriteBuffer(BufferplugSH[0],
                    Length(BufferplugSH));
                end;
              end;
            end;
          end;
        end
        else   /////////// No plugin

        begin
          //////// Convert Input format into Output format if needed:
          case StreamOut[x].Data.SampleFormat of
            0: case StreamIn[x2].Data.SampleFormat of
                1: StreamOut[x].Data.Buffer :=
                    CvInt32toFloat32(StreamOut[x].Data.Buffer);
                2: StreamOut[x].Data.Buffer :=
                    CvInt16toFloat32(StreamOut[x].Data.Buffer);
              end;
          end;
          /////// End convert.

          ///////// Finally give buffer to output
          case StreamOut[x].Data.TypePut of
            1:     /////// Give to output device
            begin
              err :=
                Pa_WriteStream(StreamOut[x].Data.HandleSt,
                @StreamOut[x].Data.Buffer[0], StreamIn[x2].Data.outframes div
                StreamIn[x2].Data.ratio);

              // if err <> 0 then status := 0;   // if you want clean buffer ...
            end;

            0:     /////// Give to wav file
              StreamOut[x].Data.FileBuffer.Data.WriteBuffer(
                StreamOut[x].Data.Buffer[0],
                StreamIn[x2].Data.outframes * StreamIn[x2].Data.Channels);
          end;
        end;
       end;
      end;

  until status = 0;

  ////////////////////////////////////// End of Loop ////////////////////////////////////////

  ////////////////////////// Terminate Thread
  if status = 0 then
  begin
         if length(PlugIn) > 0 then
      for x := 0 to high(PlugIn) do
        if Plugin[x].Name = 'soundtouch' then
        begin
          soundtouch_clear(Plugin[x].PlugHandle);
          soundtouch_destroyInstance(Plugin[x].PlugHandle);
        end;

    for x := 0 to high(StreamIn) do
      if (StreamIn[x].Data.HandleSt <> nil) then
        case StreamIn[x].Data.TypePut of
          0: case StreamIn[x].Data.LibOpen of
              0: sf_close(StreamIn[x].Data.HandleSt);
              1:
              begin
                mpg123_close(StreamIn[x].Data.HandleSt);
                mpg123_delete(StreamIn[x].Data.HandleSt);
              end;
            end;
          1:
          begin
            Pa_StopStream(StreamIn[x].Data.HandleSt);
            Pa_CloseStream(StreamIn[x].Data.HandleSt);
          end;
        end;

       for x := 0 to high(StreamOut) do
    begin
      if (StreamOut[x].Data.HandleSt <> nil) and (StreamOut[x].Data.TypePut = 1) then
      begin
       Pa_StopStream(StreamOut[x].Data.HandleSt);
       Pa_CloseStream(StreamOut[x].Data.HandleSt);
      end;
      if (StreamOut[x].Data.TypePut = 0) then
      begin
        sleep(100);
        WriteWave(StreamOut[x].Data.Filename, StreamOut[x].Data.FileBuffer);
        sleep(200);
        StreamOut[x].Data.FileBuffer.Data.Free;
        Sleep(200);
       end;
    end;

         {$IF not DEFINED(Library)}
      if EndProc <> nil then
       {$IF FPC_FULLVERSION>=20701}
        queue(EndProc);
        {$else}
      synchronize(EndProc); /////  Execute EndProc procedure
            {$endif}
            {$endif}

  isAssigned := false ;
    end;
end;

procedure Tuos_Player.onTerminate() ;
begin
FreeAndNil(uosPlayers[Index]);
uosPlayersStat[Index] := -1 ;
end;

{$IF FPC_FULLVERSION>=20701}
   constructor Tuos_Player.Create(CreateSuspended: boolean;
  const StackSize: SizeUInt);
      {$else}
     {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library)}
 constructor Tuos_Player.Create(CreateSuspended: boolean;
  const StackSize: SizeUInt);
     {$else}
     constructor Tuos_Player.Create(CreateSuspended: boolean; AParent: TObject;
       const StackSize: SizeUInt);      //// for fpGUI
    {$endif}
    {$endif}
begin
  inherited Create(CreateSuspended, StackSize);
  FreeOnTerminate := false;
  evPause := RTLEventCreate;
     {$IF FPC_FULLVERSION<20701}
     {$IF DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library) or DEFINED(Windows)}
     {$else}
   refer := aparent; //// for fpGUI
    {$endif}
    {$endif}
  isAssigned := true ;
  status := 2;
  BeginProc := nil;
  EndProc := nil;
end;

/// Create the player , PlayerIndex1 : from 0 to what your computer can do !
//// If PlayerIndex exists already, it will be overwriten...

{$IF (FPC_FULLVERSION>=20701) or DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library)}
  procedure uos_CreatePlayer(PlayerIndex : cardinal);
     {$else}
  procedure uos_CreatePlayer(PlayerIndex : cardinal ; AParent: TObject);            //// for fpGUI
    {$endif}

 var
x : integer;
begin
if PlayerIndex + 1 > length(uosPlayers) then
begin
 setlength(uosPlayers,PlayerIndex + 1) ;
 setlength(uosPlayersStat,PlayerIndex + 1) ;
end;

 {$IF ( FPC_FULLVERSION>=20701)or DEFINED(LCL) or DEFINED(ConsoleApp) or DEFINED(Library)}
     uosPlayers[PlayerIndex] := Tuos_Player.Create(true);
     {$else}
    uosPlayers[PlayerIndex] := Tuos_Player.Create(true,AParent);         //// for fpGUI
    {$endif}

   uosPlayers[PlayerIndex].Index := PlayerIndex;
   uosPlayersStat[PlayerIndex] := 1 ;
   for x := 0 to length(uosPlayersStat) -1 do
if uosPlayersStat[x] <> 1 then
begin
uosPlayersStat[x] := -1 ;
uosPlayers[x] := nil ;
end;
end;


procedure uos_BeginProc(PlayerIndex: Cardinal; Proc: TProc );
                 ///// Assign the procedure of object to execute at begin, before loop
                 //////////// PlayerIndex : Index of a existing Player
begin
  uosPlayers[PlayerIndex].BeginProc := Proc;
end;

procedure uos_EndProc(PlayerIndex: Cardinal; Proc: TProc );
                 ///// Assign the procedure of object to execute at end, after loop
                //////////// PlayerIndex : Index of a existing Player
                   //////////// InIndex : Index of a existing Input
begin
 uosPlayers[PlayerIndex].EndProc := Proc;
end;


procedure uos_LoopProcIn(PlayerIndex: Cardinal; InIndex: Cardinal; Proc: TProc );
                      ///// Assign the procedure of object to execute inside the loop
                      //////////// PlayerIndex : Index of a existing Player
                      //////////// InIndex : Index of a existing Input
begin
  uosPlayers[PlayerIndex].StreamIn[InIndex].LoopProc := Proc;
end;

procedure uos_LoopProcOut(PlayerIndex: Cardinal; OutIndex: Cardinal; Proc: TProc);
                       ///// Assign the procedure of object to execute inside the loop
                      //////////// PlayerIndex : Index of a existing Player
                      //////////// OutIndex : Index of a existing Output
begin
 uosPlayers[PlayerIndex].StreamOut[OutIndex].LoopProc := Proc;
end;

destructor Tuos_DSP.Destroy;
begin
  fftdata.Free;
end;

destructor Tuos_Player.Destroy;
var
  x: integer;
begin
  RTLeventdestroy(evPause);
  if length(StreamOut) > 0 then
    for x := 0 to high(StreamOut) do
      StreamOut[x].Free;
  if length(StreamIn) > 0 then
    for x := 0 to high(StreamIn) do
      StreamIn[x].Free;
  if length(Plugin) > 0 then
    for x := 0 to high(Plugin) do
      Plugin[x].Free;
  inherited Destroy;
end;

destructor Tuos_InStream.Destroy;
var
  x: integer;
begin
  if length(DSP) > 0 then
    for x := 0 to high(DSP) do
      DSP[x].Free;
  inherited Destroy;
end;

destructor Tuos_OutStream.Destroy;
var
  x: integer;
begin
  if length(DSP) > 0 then
    for x := 0 to high(DSP) do
      DSP[x].Free;
  inherited Destroy;
end;

procedure Tuos_Init.unloadlibCust(PortAudio : boolean; SndFile: boolean; Mpg123: boolean; SoundTouch: boolean);
               ////// Custom Unload libraries... if true, then delete the library. You may unload what and when you want...
begin
 if PortAudio = true then  Pa_Unload();
 if SndFile = true then  sf_Unload();
 if Mpg123 = true then  mp_Unload();
 if SoundTouch = true then  st_Unload();
end;

procedure Tuos_Init.unloadlib;
var
 x: integer;
begin
   if (length(uosPlayers) > 0) then
    for x := 0 to high(uosPlayers) do
     if  uosPlayersStat[x] = 1 then
     begin
      if  uosPlayers[x].Status > 0 then
    begin
    uosPlayers[x].Stop();
    sleep(300) ;
    end;
    end;

   setlength(uosPlayers, 0) ;
   setlength(uosPlayersStat, 0) ;


  Sf_Unload();
  Mp_Unload();
  Pa_Unload();
  ST_Unload();
 Set8087CW(old8087cw);

end;

function Tuos_Init.InitLib(): integer;
begin
  Result := -1;
  if (uosLoadResult.MPloadERROR = 0) then
    if mpg123_init() = MPG123_OK then
    begin
      uosLoadResult.MPinitError := 0;
      Result := 0;
    end
    else
    begin
      Result := -2;
      uosLoadResult.MPinitError := 1;
    end;

  if (uosLoadResult.PAloadERROR = 0) then
  begin
    uosLoadResult.PAinitError := Pa_Initialize();
    if uosLoadResult.PAinitError = 0 then
    begin
      Result := 0;
      DefDevOut := Pa_GetDefaultOutputDevice();
      DefDevOutInfo := Pa_GetDeviceInfo(DefDevOut);
      DefDevOutAPIInfo := Pa_GetHostApiInfo(DefDevOutInfo^.hostApi);
      DefDevIn := Pa_GetDefaultInputDevice();
      DefDevInInfo := Pa_GetDeviceInfo(DefDevIn);
      DefDevInAPIInfo := Pa_GetHostApiInfo(DefDevInInfo^.hostApi);
    end;
  end;
  if (Result = -1) and (uosLoadResult.SFloadERROR = 0) then
    Result := 0;
end;

function Tuos_Init.loadlib(): integer;
begin
  Result := -1;
   if trim(PA_FileName) <> '' then
  begin
    if not fileexists(PA_FileName) then
      uosLoadResult.PAloadERROR := 1
    else
    if Pa_Load(PA_FileName) then
    begin
      Result := 0;
      uosLoadResult.PAloadERROR := 0;
      uosDefaultDeviceOut := Pa_GetDefaultOutPutDevice();
      uosDefaultDeviceIn := Pa_GetDefaultInPutDevice();
      uosDeviceCount := Pa_GetDeviceCount();
    end
    else
      uosLoadResult.PAloadERROR := 2;
  end
  else
    uosLoadResult.PAloadERROR := -1;

  if trim(SF_FileName) <> '' then
  begin
    if not fileexists(SF_FileName) then
    begin
      Result := -1;
      uosLoadResult.SFloadERROR := 1;
    end
    else
    if Sf_Load(SF_FileName) then
    begin
      uosLoadResult.SFloadERROR := 0;
      if uosLoadResult.PAloadERROR = -1 then
        Result := 0;
    end
    else
    begin
      uosLoadResult.SFloadERROR := 2;
      Result := -1;
    end;
  end
  else
    uosLoadResult.SFloadERROR := -1;

  if trim(MP_FileName) <> '' then
  begin
    if not fileexists(MP_FileName) then
    begin
      Result := -1;
      uosLoadResult.MPloadERROR := 1;
    end
    else
    begin
      if mp_Load(Mp_FileName) then
      begin
        uosLoadResult.MPloadERROR := 0;
        if (uosLoadResult.PAloadERROR = -1) and (uosLoadResult.SFloadERROR = -1) then
          Result := 0;
      end
      else
      begin
        uosLoadResult.MPloadERROR := 2;
        Result := -1;
      end;
    end;
  end
  else
    uosLoadResult.MPloadERROR := -1;

  if trim(Plug_ST_FileName) <> '' then
  begin
    if not fileexists(Plug_ST_FileName) then
    begin
      Result := -1;
      uosLoadResult.STloadERROR := 1;
    end
    else
    if ST_Load(Plug_ST_FileName) then
    begin
      if (uosLoadResult.MPloadERROR = -1) and (uosLoadResult.PAloadERROR = -1) and
        (uosLoadResult.SFloadERROR = -1) then
        Result := 0;
      uosLoadResult.STloadERROR := 0;
    end
    else
    begin
      uosLoadResult.STloadERROR := 2;
      Result := -1;
    end;
  end
  else
    uosLoadResult.STloadERROR := -1;

  if Result = 0 then
    Result := InitLib();
end;

function uos_loadlib(PortAudioFileName: String; SndFileFileName: String; Mpg123FileName: String; SoundTouchFileName: String) : integer;
  begin
   result := -1 ;
   if not assigned(uosInit) then begin
   old8087cw := Get8087CW;
   Set8087CW($133f);
   uosInit := TUOS_Init.Create;   //// Create Iibraries Loader-Init
   end;
   uosInit.PA_FileName := PortAudioFileName;
   uosInit.SF_FileName := SndFileFileName;
   uosInit.MP_FileName := Mpg123FileName;
   uosInit.Plug_ST_FileName := SoundTouchFileName;

  result := uosInit.loadlib ;
  end;

procedure uos_unloadlib() ;
begin
 uosInit.unloadlib ;
 uosInit.free;
end;

procedure uos_unloadlibCust(PortAudio : boolean; SndFile: boolean; Mpg123: boolean; SoundTouch: boolean);
                    ////// Custom Unload libraries... if true, then delete the library. You may unload what and when you want...
begin
 uosInit.unloadlibcust(PortAudio, SndFile, Mpg123, SoundTouch) ;
end;

procedure uos_GetInfoDevice();
var
  x: cardinal;
  devinf: PPaDeviceInfo;
  apiinf: PPaHostApiInfo;
begin
  x := 0;
  SetLength(uosDeviceInfos, Pa_GetDeviceCount());

  uosDefaultDeviceOut := Pa_GetDefaultOutPutDevice();
  uosDefaultDeviceIn := Pa_GetDefaultInPutDevice();

  uosDeviceCount := Pa_GetDeviceCount();

  while x < Pa_GetDeviceCount() do
  begin
    uosDeviceInfos[x].DeviceNum := x;

    devinf := Pa_GetDeviceInfo(x);
    apiinf := Pa_GetHostApiInfo(devinf^.hostApi);

    uosDeviceInfos[x].HostAPIName := apiinf^._name;
    uosDeviceInfos[x].DeviceName := devinf^._name;

    if x = uosDefaultDeviceIn then
      uosDeviceInfos[x].DefaultDevIn := True
    else
      uosDeviceInfos[x].DefaultDevIn := False;

    if x = uosDefaultDeviceOut then
      uosDeviceInfos[x].DefaultDevOut := True
    else
      uosDeviceInfos[x].DefaultDevOut := False;

    uosDeviceInfos[x].ChannelsIn := devinf^.maxInputChannels;
    uosDeviceInfos[x].ChannelsOut := devinf^.maxOutPutChannels;
    uosDeviceInfos[x].SampleRate := devinf^.defaultSampleRate;
    uosDeviceInfos[x].LatencyHighIn := devinf^.defaultHighInputLatency;
    uosDeviceInfos[x].LatencyLowIn := devinf^.defaultLowInputLatency;
    uosDeviceInfos[x].LatencyHighOut := devinf^.defaultHighOutputLatency;
    uosDeviceInfos[x].LatencyLowOut := devinf^.defaultLowOutputLatency;

    if uosDeviceInfos[x].ChannelsIn = 0 then
    begin
    if uosDeviceInfos[x].ChannelsOut = 0 then
     uosDeviceInfos[x].DeviceType:= 'None' else  uosDeviceInfos[x].DeviceType:= 'Out' ;
    end  else
    begin
    if uosDeviceInfos[x].ChannelsOut = 0 then
     uosDeviceInfos[x].DeviceType:= 'In' else  uosDeviceInfos[x].DeviceType:= 'In/Out' ;
    end ;
  Inc(x);
  end;
end;

function uos_GetInfoDeviceStr() : String ;
var
  x : cardinal ;
devtmp , bool1, bool2 : string;
begin
 uos_GetInfoDevice() ;
  x := 0;
  devtmp := '';
 while   x < length(uosDeviceInfos) do
 begin
 if uosDeviceInfos[x].DefaultDevIn then bool1 := 'Yes' else bool1 := 'No';
 if uosDeviceInfos[x].DefaultDevOut then bool2 := 'Yes' else bool2 := 'No';

 devtmp := devtmp +
 'DeviceNum: ' + inttostr(uosDeviceInfos[x].DeviceNum) + ' ǀ' +
 ' Name: ' + uosDeviceInfos[x].DeviceName +  ' ǀ' +
 ' Type: ' + uosDeviceInfos[x].DeviceType + ' ǀ' +
 ' DefIn: ' + bool1 + ' ǀ' +
 ' DefOut: ' + bool2 + ' ǀ' +
 ' ChanIn: ' +  IntToStr(uosDeviceInfos[x ].ChannelsIn)+ ' ǀ' +
 ' ChanOut: ' +  IntToStr(uosDeviceInfos[x].ChannelsOut) + ' ǀ' +
 ' SampleRate: ' +  floattostrf(uosDeviceInfos[x].SampleRate, ffFixed, 15, 0) + ' ǀ' +
 ' LatencyHighIn: ' + floattostrf(uosDeviceInfos[x].LatencyHighIn, ffFixed, 15, 8) + ' ǀ' +
 ' LatencyHighOut: ' + floattostrf(uosDeviceInfos[x].LatencyHighOut, ffFixed, 15, 8)+ ' ǀ' +
 ' LatencyLowIn: ' + floattostrf(uosDeviceInfos[x].LatencyLowIn, ffFixed, 15, 8)+ ' ǀ' +
 ' LatencyLowOut: ' + floattostrf(uosDeviceInfos[x].LatencyLowOut, ffFixed, 15, 8)+ ' ǀ' +
 ' HostAPI: ' + uosDeviceInfos[x].HostAPIName ;
 if x < length(uosDeviceInfos)-1 then  devtmp := devtmp +  #13#10 ;
 Inc(x);
 end;
 result := devtmp ;
end;

constructor Tuos_Init.Create;
begin
  SetExceptionMask(GetExceptionMask + [exZeroDivide] + [exInvalidOp] +
    [exDenormalized] + [exOverflow] + [exPrecision]);
  uosLoadResult.PAloadERROR := -1;
  uosLoadResult.SFloadERROR := -1;
  uosLoadResult.STloadERROR := -1;
  uosLoadResult.MPloadERROR := -1;
  uosLoadResult.PAinitError := -1;
  uosLoadResult.MPinitError := -1;
  setlength(uosPlayers,0) ;
  setlength(uosPlayersStat,0) ;
  PA_FileName := ''; // PortAudio
  SF_FileName := ''; // SndFile
  MP_FileName := ''; // Mpg123
  Plug_ST_FileName := ''; // Plugin SoundTouch
end;

end.