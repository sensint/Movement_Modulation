// This is the code for studying the effect of granularity. Different combinations of Frequency
// bin numbers will be displayed to the participants. They can change between the conditions
// by pressing the enter key.

//=================================
// Important:
// -Change the .txt file based on your preference.
// -Change the screen size based on your preference.
// -Keep in mind to update the sensor range in Arduino code based on your screen size.
//=================================

import processing.serial.*;
import java.util.ArrayList;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.Rectangle;

Serial port;
int taskCounter = 0;
ArrayList<Integer> conditions = new ArrayList<Integer>();
ArrayList<Integer> frequencies = new ArrayList<Integer>();
ArrayList<Integer> bins = new ArrayList<Integer>();
boolean serialConnected = false;
int retryCount = 0;
int maxRetries = 10;
int lastReceivedTime;
int timeout = 5000;
int sendInterval = 5;
int lastSendTime = 0;

boolean experimentStarted = false;  // Flag to check if the experiment has started

int minX, maxX, xDifference;

void setup() {
  size(500, 500);
  //noCursor();
  frameRate(500);  // Set the frame rate to 500 Hz

  // Calculate the min and max x-coordinates across all screens
  calculateScreenBounds();

  String[] lines = loadStrings("task_conditions1.txt");
  if (lines != null) {
    for (String line : lines) {
      String[] parts = line.split(",");
      if (parts.length == 3) {
        int condition = int(parts[0].trim());
        int frequency = int(parts[1].trim());
        int bin = int(parts[2].trim());
        conditions.add(condition);
        frequencies.add(frequency);
        bins.add(bin);
      }
    }
  }

  connectToSerialPort();
  startNewTask();
}

void draw() {
  background(255);

  Point mouseLocation = MouseInfo.getPointerInfo().getLocation();
  int mouseXGlobal = mouseLocation.x;

  // Map the mouseXGlobal to the range 0 to xDifference
  float mappedMouseX = map(mouseXGlobal, minX, maxX, 0, xDifference);

  if (!experimentStarted) {
    drawStartButton();
    return;  // Skip the rest of the draw loop if the experiment hasn't started
  }

  if (taskCounter >= conditions.size()) {
    sendEndSignal();
    fill(0.5);
    textSize(60);
    textAlign(CENTER, CENTER);
    text("Experiment Completed", width / 2, height / 2 - 300);
    text("Thank You!", width / 2, height / 2 - 150);
    noLoop();
    return;
  }

  fill(0);
  textSize(32);
  textAlign(CENTER, TOP);
  text("Task Number: " + nf(taskCounter + 1, 0, 0), width / 4, 50);
  text("Condition: " + conditions.get(taskCounter), width / 4, 100);
  text("Frequency: " + frequencies.get(taskCounter), width / 4, 150);
  text("Bins: " + bins.get(taskCounter), width / 4, 200);

  if (serialConnected && port != null && millis() - lastSendTime > sendInterval) {
    String data = mappedMouseX + "," + conditions.get(taskCounter) + "," + frequencies.get(taskCounter) + "," + bins.get(taskCounter);
    try {
      port.write(data + "\r\n");
      lastSendTime = millis();
      println(data);

      port.clear();  // Clear the buffer after sending data

    } catch (Exception e) {
      reconnectToSerialPort();
    }
  }

  if (millis() - lastReceivedTime > timeout) {
    reconnectToSerialPort();
  }
}

void mousePressed() {
  if (!experimentStarted && mouseX <= 50 && mouseY >= 0) {  // Check if the start button is clicked
    experimentStarted = true;
    return;  // Skip the rest of the mousePressed function if the start button is clicked
  }
}

void keyPressed() {
  if (key == ENTER) {
    taskCounter++;
    if (taskCounter < conditions.size()) {
      startNewTask();
    }
  }
}

void drawStartButton() {
  fill(0, 255, 0, 80);
  rect(0, 0, 50, height);
  fill(0);
  textSize(32);
  textAlign(CENTER, CENTER);
  text("Click Inside the", 190, height / 2 - 15);
  text("Green Box to Begin", 190, height / 2 + 15);
}

void startNewTask() {
  if (taskCounter >= conditions.size()) {
    return;
  }

  // Include additional setup for each new task if needed.
}

void connectToSerialPort() {
  String[] ports = Serial.list();
  while (!serialConnected && retryCount < maxRetries) {
    if (ports.length > 0) {
      try {
        port = new Serial(this, ports[0], 115200);
        port.bufferUntil('\n');
        serialConnected = true;
        lastReceivedTime = millis();
      } catch (Exception e) {
        retryCount++;
        delay(10);
      }
    } else {
      retryCount++;
      delay(10);
    }
  }

  if (!serialConnected) {
    // Handle failed connection attempts
  }
}

void reconnectToSerialPort() {
  if (port != null) {
    port.stop();
  }
  serialConnected = false;
  retryCount = 0;
  connectToSerialPort();
}

void sendEndSignal() {
  if (serialConnected && port != null) {
    String endData = "0,0,0,0";
    try {
      port.write(endData + "\r\n");
      println(endData);
    } catch (Exception e) {
      reconnectToSerialPort();
    }
  }
}

void exit() {
  if (port != null) {
    port.stop();
  }
  super.exit();
}

void calculateScreenBounds() {
  // Get all screens
  GraphicsDevice[] screens = GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices();
  minX = Integer.MAX_VALUE;
  maxX = Integer.MIN_VALUE;

  // Find the min and max x coordinates across all screens
  for (GraphicsDevice screen : screens) {
    Rectangle bounds = screen.getDefaultConfiguration().getBounds();
    if (bounds.x < minX) {
      minX = bounds.x;
    }
    if (bounds.x + bounds.width > maxX) {
      maxX = bounds.x + bounds.width;
    }
  }

  // Calculate the absolute difference
  xDifference = maxX - minX;
}
