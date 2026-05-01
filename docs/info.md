<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->


## How it works

Read keypad inputs, compare the entered code with the stored password, and control the access status outputs.
If the code is correct, the access granted LED turns ON. Otherwise, the access denied LED turns ON.


## How to test

Enter a password using the keypad and observe the output LEDs.
The green LED should turn ON for the correct password, while the red LED should turn ON for an incorrect password.
Press the reset button to clear the input and test again.

## External hardware

Use a 4x4 keypad connected to the inputs, along with LEDs for access status indication and a push button for reset.

