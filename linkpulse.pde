#include <Ethernet.h>
#include "Dhcp.h"  // uses DHCP code from: http://blog.jordanterrell.com/post/Arduino-DHCP-Library-Version-04.aspx 
#include <TextFinder.h>

byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte server[] = {
  87,238,48,70 }; // lp1.linkpulse.com
char* channelIDs[]={
  "69fc88066df1d55f","7e26f1a83f4c072f","7aab030d8f1f4c81","69fc88066df1d55f"};  
long waitTill[4] = {
  0, 0, 0, 0};
long stateclicks[4] = {
  -1, -1, -1, -1};
long prevStateclicks[4] = {
  -1, -1, -1, -1};
long channelWaitTill = 0;
boolean channelSelect = true;

int channel = 0;
long lastReadingAt = 0;
long delayT = 0;
int lastChannel = -1;

Client client(server, 80);

TextFinder  finder( client );  

void setup()
{
  pinMode(2, OUTPUT); 
  pinMode(3, OUTPUT); 
  Serial.begin(2400);
  welcomeScreen();
  if(Dhcp.beginWithDHCP(mac) == 1) {  // begin method returns 1 if successful  
    Serial.println("got IP address, connecting...");
    delay(5000);  
  }
  else {
    Serial.println("unable to acquire ip address!");
    while(true)
      ;  // do nothing
  }
}

void sendCommand(int address, int command, int parameter) {
  Serial.print(13,BYTE);
  Serial.print(address,BYTE);
  Serial.print(command,BYTE);
  Serial.print(parameter,BYTE);
  Serial.print(256-(13+address+command+parameter) % 256,BYTE);
  Serial.print(13,BYTE);
  Serial.print(address,BYTE);
  Serial.print(command,BYTE);
  Serial.print(parameter,BYTE);
  Serial.print(256-(13+address+command+parameter) % 256,BYTE);
  Serial.print(13,BYTE);
  Serial.print(address,BYTE);
  Serial.print(command,BYTE);
  Serial.print(parameter,BYTE);
  Serial.print(256-(13+address+command+parameter) % 256,BYTE);
  Serial.print(13,BYTE);
  Serial.print(address,BYTE);
  Serial.print(command,BYTE);
  Serial.print(parameter,BYTE);
  Serial.print(256-(13+address+command+parameter) % 256,BYTE);
}

void show(int number) {
  sendCommand(4,'A',(number/1000)+48);
  sendCommand(3,'A',((number/100) % 10 )+48);
  sendCommand(2,'A',((number/10) % 10 )+48);
  sendCommand(1,'A',(number % 10)+48);
  strobe();
}

void strobe() {
  delay(100);
  sendCommand(8,'S',1); 
}

void welcomeScreen() {
  sendCommand(4,'B',79); // H 
  sendCommand(3,'B',111); // A
  sendCommand(2,'B',193); // L
  sendCommand(1,'B',193); // L
  strobe();
}

long getStateclicks(int channel) {
  long stateclicks = 0;
  long time = 0;
  boolean ok = false;
  if (client.connect()) {
    client.print("GET /lpFeeder/d9c853a68e27d39c/");
    client.print(channelIDs[channel]);
    client.println(" HTTP/1.0");  
    client.println("Host: lp1.linkpulse.com");
    client.println();
  } 
  else {
    Serial.println(" connection failed");
  } 
  if (client.connected()) {
    time = millis();
    if(finder.find("<description>stateclicks: ") )
    {      
      stateclicks = finder.getValue();
      Serial.print("Stateclicks are ");  // and echo it to the serial port.
      Serial.println(stateclicks);
      ok = true;
    } 
    else
      Serial.print("Could not find stateclicks field"); 
  }
  else {
    Serial.println("Disconnected"); 
  }
  Serial.println(millis()-time);
  client.stop();
  client.flush();  
  if(ok) 
    return stateclicks;
  else
    return -1; 
}

void setPoint(int channel) {
  sendCommand(1,'P',0);
  sendCommand(2,'P',0);
  sendCommand(3,'P',0);
  sendCommand(4,'P',0);
  sendCommand(4-channel,'P',255);
  strobe();
  Serial.print("Channel no ");
  Serial.print(channel+1);
  Serial.println();
}

int getChannelReading() {
  channel = map(analogRead(0),0,1023,0,4);    // read the value from the sensor
  if(channel==4)
    channel=3; 
  return channel;
}

void showMinus() {
  sendCommand(1,'B',2);
  sendCommand(2,'B',2);
  sendCommand(3,'B',2);
  sendCommand(4,'B',2);
  strobe();
}

void showChannelNo(int channel) {
  sendCommand(4,'B',225); // C
  sendCommand(3,'B',75);  // h
  sendCommand(2,'B',0);   // (space)
  sendCommand(1,'A',49+channel); // (number)
  strobe();
}

void showTrend(long now, long prev) {
  Serial.println("showTrend");
  digitalWrite(2, LOW);
  digitalWrite(3, LOW);

  if(now == -1 || prev == -1)
    return;
  if(now > prev) {
    digitalWrite(2, HIGH);
    digitalWrite(3, LOW);
    Serial.println("Trend up");
  }
  else if(now < prev)
  {
    digitalWrite(2, LOW);
    digitalWrite(3, HIGH);
    Serial.println("Trend down");
  }
}

void loop()
{ 
  channel = getChannelReading();
  if(channel != lastChannel)
  {
    setPoint(channel); 
    Serial.println(channel+1);
    lastChannel = channel;  
    showChannelNo(channel);
    channelSelect = true;
    channelWaitTill = millis()+3500;
  }
  if(channelSelect && millis()>channelWaitTill) {
    if(stateclicks[channel] == -1)
      showMinus();
    else {
      show(stateclicks[channel]/10);
    }
    showTrend(stateclicks[channel], prevStateclicks[channel]);    
    channelSelect = false;
  }
  if(!channelSelect && millis()>waitTill[channel]) {
    stateclicks[channel] = getStateclicks(channel);
    if(stateclicks[channel]>-1) {
      show(stateclicks[channel]/10);
      showTrend(stateclicks[channel], prevStateclicks[channel]);
      prevStateclicks[channel] = stateclicks[channel];
      waitTill[channel] = millis() + 300000;
    }
    else 
      waitTill[channel] = millis() + 30000;
  }
}