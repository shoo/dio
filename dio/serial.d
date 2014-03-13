/*******************************************************************************
 * 
 */
module dio.serial;

import std.typecons;
import dio.file;

import core.sys.windows.windows;
enum: BYTE
{
	EVENPARITY  = 2,
	MARKPARITY  = 3,
	NOPARITY    = 0,
	ODDPARITY   = 1,
	SPACEPARITY = 4,
}
enum: BYTE
{
	ONESTOPBIT   = 0,
	ONE5STOPBITS = 1,
	TWOSTOPBITS  = 2,
}
extern (Windows) struct DCB
{
	import std.bitmanip;
	DWORD DCBlength = DCB.sizeof;
	DWORD BaudRate  = 19200;
	mixin(bitfields!(
	    DWORD, "fBinary",           1,
	    DWORD, "fParity",           1,
	    DWORD, "fOutxCtsFlow",      1,
	    DWORD, "fOutxDsrFlow",      1,
	    DWORD, "fDtrControl",       2,
	    DWORD, "fDsrSensitivity",   1,
	    DWORD, "fTXContinueOnXoff", 1,
	    DWORD, "fOutX",             1,
	    DWORD, "fInX",              1,
	    DWORD, "fErrorChar",        1,
	    DWORD, "fNull",             1,
	    DWORD, "fRtsControl",       2,
	    DWORD, "fAbortOnError",     1,
	    DWORD, "fDummy2",           17));
	WORD  wReserved;
	WORD  XonLim    = 512;
	WORD  XoffLim   = 512;
	BYTE  ByteSize  = 8;
	BYTE  Parity    = NOPARITY;
	BYTE  StopBits  = ONESTOPBIT;
	char  XonChar   = '\x11';
	char  XoffChar  = '\x13';
	char  ErrorChar = '\x00';
	char  EofChar   = '\x03';
	char  EvtChar   = '\x02';
	WORD  wReserved1;
}
static assert(DCB.sizeof == 28);

extern (Windows) BOOL GetCommState(HANDLE hFile, DCB* lpDCB);
extern (Windows) BOOL SetCommState(HANDLE hFile, DCB* lpDCB);

struct COMMTIMEOUTS
{
	DWORD ReadIntervalTimeout;
	DWORD ReadTotalTimeoutMultiplier;
	DWORD ReadTotalTimeoutConstant;
	DWORD WriteTotalTimeoutMultiplier;
	DWORD WriteTotalTimeoutConstant;
}

extern (Windows) BOOL GetCommTimeouts(HANDLE hFile, COMMTIMEOUTS* lpCommTimeouts);
extern (Windows) BOOL SetCommTimeouts(HANDLE hFile, COMMTIMEOUTS* lpCommTimeouts);

extern (Windows) BOOL SetupComm(
  HANDLE hFile,     // 通信デバイスのハンドル
  DWORD dwInQueue,  // 入力バッファのサイズ
  DWORD dwOutQueue  // 出力バッファのサイズ
);


struct SerialSettings
{
	enum Parity
	{
		nothing,
		odd,
		even
	}
	enum StopBitLength
	{
		one,
		oneHalf,
		two
	}
	uint          baudRate;
	uint          byteSize;
	Parity        parity;
	StopBitLength stopBits;
}

/*******************************************************************************
 * 
 */
struct Serial
{
	File handle;
	mixin Proxy!handle;
	
	this(string fname, in char[] mode = "r")
	{
		handle = File(fname, mode);
	}
	
	void settings(SerialSettings s) @property
	{
		DCB dcb;
		GetCommState(handle.handle, &dcb);
		with (dcb)
		{
			//fBinary           = 1;
			//fParity           = 1;
			//fOutxCtsFlow      = 0;
			//fOutxDsrFlow      = 0;
			//fDtrControl       = 0;
			//fDsrSensitivity   = 0;
			//fTXContinueOnXoff = 0;
			//fOutX             = 0;
			//fInX              = 0;
			//fErrorChar        = 1;
			//fNull             = 1;
			//fRtsControl       = 1;
			//fAbortOnError     = 1;
			
			BaudRate = s.baudRate;
			ByteSize = cast(BYTE)s.byteSize;
			Parity   = s.parity == SerialSettings.Parity.even ? EVENPARITY
			         : s.parity == SerialSettings.Parity.odd  ? ODDPARITY
			         : NOPARITY;
			StopBits = s.stopBits == SerialSettings.StopBitLength.one     ? ONESTOPBIT
			         : s.stopBits == SerialSettings.StopBitLength.oneHalf ? ONE5STOPBITS
			         : TWOSTOPBITS;
		}
		SetCommState(handle.handle, &dcb);
		SetupComm(handle.handle, 512, 512);
		COMMTIMEOUTS timeout;
		with (timeout)
		{
			ReadIntervalTimeout         = 1;
			ReadTotalTimeoutMultiplier  = 1;
			ReadTotalTimeoutConstant    = 0;
			WriteTotalTimeoutMultiplier = 0;
			WriteTotalTimeoutConstant   = 0;
		}
		SetCommTimeouts(handle.handle, &timeout);
	}
	
	SerialSettings settings() @property
	{
		SerialSettings ret;
		DCB dcb;
		GetCommState(handle.handle, &dcb);
		with (ret)
		{
			baudRate = dcb.BaudRate;
			byteSize = dcb.ByteSize;
			parity   = dcb.Parity == EVENPARITY ? Parity.even
			         : dcb.Parity == ODDPARITY  ? Parity.odd
			         : Parity.nothing;
			stopBits = dcb.StopBits == ONESTOPBIT   ? StopBitLength.one
			         : dcb.StopBits == ONE5STOPBITS ? StopBitLength.oneHalf
			         : StopBitLength.two;
		}
		return ret;
	}
}
