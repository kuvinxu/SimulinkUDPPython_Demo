# Simulink-Python UDP Communication System

## Overview

This project demonstrates a simulation system using MATLAB/Simulink and Python, connected via UDP for real-time data exchange. The MATLAB script runs a Simulink model `car.slx` for 50 episodes, randomly setting a Gain parameter each time. Python receives state parameters from Simulink, computes a control command using `sin(sim_t)`, and sends it back to car.slx. The system includes handshake mechanisms for synchronization.

The project is designed for MATLAB R2020a and Python 3.x, with support for Instrument Control Toolbox in MATLAB.

## Features

- UDP communication between MATLAB and Python for grip handshaking, control signals, and state parameters.
- Random Gain setting in Simulink model for each episode.
- Python computes control as `sin(sim_t)` and sends to Simulink.
- Data logging in MATLAB for training analysis (gain, inputs, outputs, times).
- Error handling for socket binding and simulation failures.

## Requirements

### MATLAB

- MATLAB R2020a
- Simulink
- Instrument Control Toolbox (for UDP functions)
- The Simulink model `car.slx` must be in the working directory.

### Python

- Python 3.x

- Libraries: `socket`, `struct`, `time`, `math`, `numpy`

- Install dependencies:
  
  ```
  pip install numpy
  ```

### Environment

- Tested on Windows (for `netstat` and `taskkill` commands).
- Ensure firewall allows UDP ports 12345-12351.

## Installation

1. Clone the repository:
   
   ```
   git clone https://github.com/your-repo/simulink-python-udp-system.git
   cd simulink-python-udp-system
   ```

2. Place the Simulink model `car.slx` in the repository root.

3. Install Python dependencies:
   
   ```
   pip install numpy
   ```

## Usage

1. **UDP prots in the system:**

![](C:\Users\pc\AppData\Roaming\marktext\images\2025-08-21-01-03-57-image.png)

2. **Start the simulation**
   
   - **Run MATLAB Script (first):

3- - open MATLAB, set current directory to the repository, and run `runDemo.m`.Run 

- open MATLAB, set current directory to the repository, and run `runDemo.m`.Run 
  
  Run MATLAB Script (first):
  
  - Run MATLAB Script (first):

- Python Script** (2nd):

```
python pythonControl.py
```

- This binds UDP ports and waits for MATLAB handshake.
3. **Execution Flow**:
- MATLAB sends handshake `[0, -1]` to Python via UDP.
- Python receives, sends confirmation `[0, -1]` back.
- MATLAB loads `car.slx`, runs 50 episodes:
  - Sets random Gain (1~100).
  - Sends episode start signal.
  - Runs simulation.
  - Logs data.
  - Sends episode end signal.
- MATLAB sends final end signal `[51, -2]`.
- Python receives signals, computes and sends control, updates status.
4. **Data Output**:
- MATLAB saves `training_data` struct in workspace (gain, inputs, outputs, times for each episode).

## File Structure

- `matlabmian.m`: MATLAB main script for UDP communication and Simulink simulation.
- `pythonControl.py`: Python script for UDP reception, control computation, and response.
- `car.slx`: Simulink model (not included; user-provided).
- `README.md`: This document.

## Troubleshooting

- **Port Occupation**:
  
  - Run:
    
    ```
    netstat -aon | findstr "12345 12346 12347 12348 12349 12350 12351"
    ```
  
  - Kill occupying processes:
    
    ```
    taskkill /PID <PID> /F
    ```

- **Firewall**:
  
  - Allow UDP ports:
    
    ```
    netsh advfirewall firewall add rule name="Allow UDP 12345-12351" dir=in action=allow protocol=UDP localport=12345-12350
    ```

- **UDP Binding Failure**:
  
  - Check socket errors in Python or UDP open failures in MATLAB.

- **Simulink Errors**:
  
  - Ensure `car.slx` has 3 logged signals (inputs, outputs, times).
    
    ![](C:\Users\pc\AppData\Roaming\marktext\images\2025-08-21-00-57-49-image.png)

- **Byte Order**:
  
  - Both sides use little-endian, no need for `swapbytes` in MATLAB.

## Notes

- For debugging, enable `system('netstat -aon | findstr "ports"')` outputs.
- Project tested on Windows; adjust for other OS (e.g., `netstat` to `ss` on Linux).

## License

MIT License. See LICENSE for details.

## Contact

For issues, open a GitHub issue or contact the maintainer.
