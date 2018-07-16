#include "RadioMSG.h"
#define NEW_PRINTF_SEMANTICS
#include "printf.h"


configuration SmartLightsAppC {}
implementation {
  components MainC, SmartLightsC as App, LedsC;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  
  components SerialPrintfC;
  components ActiveMessageC;
  
  App.Boot -> MainC.Boot;
  
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;

  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;

  App.Packet -> AMSenderC;
}


