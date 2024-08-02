// This is the code for running a pilot study. The participants have freedom in
// varying frequency and bin numbers. Once the participant is confident about a combination
// of frequency and bin values values, he/she can press space key to save those values.
// Every participant has 12 selections.

//=================================
// Important:
// -Change the participant name to save the text file with a proper name.
// -Change the screen size based on your preference.
// -Keep in mind to update the sensor range in Arduino code based on your screen size.
//=================================

import processing.serial.*;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.Rectangle;
import java.io.PrintWriter;

Serial port;

int frequency = 80;
int binNumber = 40;
boolean serialConnected = false;
int retryCount = 0;
int maxRetries = 10;
int lastReceivedTime;
int timeout = 5000;
int sendInterval = 5;
int lastSendTime = 0;

boolean experimentStarted = false;  // Flag to check if the experiment has started
boolean frequencySelected = true;   // Start with Frequency slider selected
int minX, maxX, xDifference;

int spacePressCount = 0;  // Count of space key presses
int remainingCount = 0;
PrintWriter output;       // File writer for saving data

void setup() {
  size(1080, 1080);  // Set the window size
  frameRate(500);  // Set the frame rate

  // Calculate the min and max x-coordinates across all screens
  calculateScreenBounds();

  connectToSerialPort();
  
  // Initialize the file writer
  output = createWriter("Participant 1.txt");
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

  // Draw sliders and current values
  drawVerticalSlider("Frequency", 80, 200, frequency, frequencySelected, width / 4, height / 3);
  drawVerticalSlider("Bin Number", 40, 240, binNumber, !frequencySelected, (3 * width) / 4, height / 3);

  // Show space press count
  fill(0);
  textSize(48);  // text size
  textAlign(RIGHT, TOP);
  remainingCount = 12 - spacePressCount;
  text("Remaining Choices: " + remainingCount, width - 20, 20);

  // Send data to serial port
  if (serialConnected && port != null && millis() - lastSendTime > sendInterval) {
    int condition = 3; // Hardcode 3 for the second column of data
    String data = mappedMouseX + "," + condition + "," + frequency + "," + binNumber;
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
  if (key == ESC) {
    exit();  // Stop the code from running when ESC is pressed
  }
  if (key == TAB) {   // switch between sliders
    frequencySelected = !frequencySelected;  // Switch between Frequency and Bin Number sliders
  }
  if (keyCode == UP) {  // increase slider values with UP key
    if (frequencySelected) {
      frequency = constrain(frequency + 1, 80, 200);
    } else {
      binNumber = constrain(binNumber + 1, 40, 240);
    }
  }
  if (keyCode == DOWN) {  // decrease slider values with UP key
    if (frequencySelected) {
      frequency = constrain(frequency - 1, 80, 200);
    } else {
      binNumber = constrain(binNumber - 1, 40, 240);
    }
  }
  if (key == ' ') {   // save the combinations if space key is pressed
    spacePressCount++;
    output.println(frequency + "," + binNumber);
    output.flush();  // Ensure data is written to file

    if (spacePressCount >= 12) {
      output.close();
      finishExperiment();
    }
  }
}

void drawStartButton() {
  fill(0, 255, 0, 80);
  rect(0, 0, 50, height);
  fill(0);
  textSize(64);  // text size
  textAlign(CENTER, CENTER);
  text("Click Inside the", width / 2, height / 2 - 40);
  text("Green Box to Begin", width / 2, height / 2 + 40);
}

void drawVerticalSlider(String label, int minVal, int maxVal, int currentValue, boolean isSelected, int xPosition, int sliderHeight) {
  int sliderWidth = 80;  // slider width
  int sliderX = xPosition - sliderWidth / 2;
  int sliderY = (height - sliderHeight) / 2;
  
  // Draw slider background
  fill(255, 255, 200);  // Light yellow background
  stroke(0);
  strokeWeight(1);  // Stroke weight
  rect(sliderX, sliderY, sliderWidth, sliderHeight);
  
  // Draw slider value background with a gradient red color
  int sliderValueY = (int)map(currentValue, minVal, maxVal, sliderY + sliderHeight, sliderY);
  for (int i = sliderY + sliderHeight; i > sliderValueY; i--) {
    float inter = map(i, sliderY + sliderHeight, sliderValueY, 0, 1);
    int c = lerpColor(color(255, 200, 200), color(255, 0, 0), inter);  // Gradient color
    stroke(c);
    line(sliderX, i, sliderX + sliderWidth, i);
  }
  
  // Draw the slider border
  stroke(0);
  strokeWeight(1);
  noFill();
  rect(sliderX, sliderY, sliderWidth, sliderHeight);
  
  // Draw label and value
  textAlign(CENTER, CENTER);
  textSize(48);  // text size
  fill(0);
  text(label, xPosition, sliderY - 60);
  
  
  String valueText = (label.equals("Frequency")) ? currentValue + " Hz" : String.valueOf(currentValue);
  text(valueText, xPosition, sliderY + sliderHeight + 60);
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

void finishExperiment() {
  fill(0);
  textSize(64);  // Large text size for end message
  textAlign(CENTER, CENTER);
  text("Successful!", width / 2, height / 2 - 40);
  text("Thank You!", width / 2, height / 2 + 40);
  noLoop();  // Stop the draw loop
  
  // Send end signal to serial port
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
  if (output != null) {
    output.close();  // Ensure the file is closed properly
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
