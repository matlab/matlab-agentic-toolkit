# Skills Catalog

The skills catalog organizes agent skills into groups. Each group contains one or more skill folders, each with a `SKILL.md` file and a `manifest.yaml` file. The `manifest.yaml` file contains metadata about the skill.

## Skills

<!-- BEGIN SKILLS -->
### MATLAB Core ([`matlab-core`](./matlab-core/))

Create, debug, test, review, and manage MATLAB&reg; code and installations

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-create-live-script` | Create plain-text MATLAB Live Scripts with rich text, LaTeX equations, and inline figures. |
| `matlab-debug-code` | Diagnose MATLAB errors and unexpected behavior. |
| `matlab-install-products` | Install MathWorks&reg; products from the command line using MATLAB Package Manager (mpm). |
| `matlab-list-products` | Show all installed MATLAB products and support packages for a given MATLAB installation folder. |
| `matlab-read-documentation` | Fetch and navigate MathWorks documentation specific for your MATLAB release to determine correct function syntax, complete workflows, and determine best practices for working in MATLAB and Simulink&reg; software. |
| `matlab-review-code` | Review MATLAB code for quality, performance, maintainability, and adherence to MathWorks coding standards. |
| `matlab-write-test` | Generate and run MATLAB unit tests using the matlab.unittest framework. |

### MATLAB App Building ([`matlab-app-building`](./matlab-app-building/))

Build MATLAB apps programmatically using UI components, layouts, callbacks, and web integration

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-apply-theme` | Apply color palettes, brand theming, dark mode, and conditional styling to MATLAB charts and uifigure apps. |
| `matlab-build-app` | Build MATLAB apps with guided architecture selection (UIFigure or UIHTML), layout archetypes, and structured implementation plans. For UIFigure apps, optionally serialize to App Designer format (.mlapp or plain-text). |
| `matlab-build-chart` | Create and customize MATLAB charts with correct axes handling, modern layout, annotations, interactivity, and animation patterns. |

### MATLAB Data Import and Analysis ([`matlab-data-import-and-analysis`](./matlab-data-import-and-analysis/))

Import, export, and analyze data in MATLAB using tables, timetables, filtering, aggregation, and time-series operations

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-data` | Analyze data in MATLAB using tables, timetables, numeric arrays, and gridded data — filtering, aggregation, smoothing, cleaning, and time-series operations. |
| `matlab-choose-big-data-solution` | Choose the right MATLAB tool for processing large tabular data that may not fit in memory. |
| `matlab-import-export-data` | Import and export tabular, structured, and binary data with cross-tool fidelity. |
| `matlab-secure-credentials` | Store, retrieve, and pass credentials securely in MATLAB using the built-in MATLAB vault. |

### MATLAB Environment and Settings ([`matlab-environment-and-settings`](./matlab-environment-and-settings/))

Diff MATLAB settings between releases and migrate startup scripts to correct setting paths

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-migrate-settings` | Diff MATLAB settings between releases and update startup scripts to use the correct setting paths. |

### MATLAB External Language Interfaces ([`matlab-external-language-interfaces`](./matlab-external-language-interfaces/))

Call Python&reg; libraries from MATLAB and upgrade MEX files to the interleaved complex API

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-call-python` | Call Python libraries from MATLAB using the py. interface. |
| `matlab-upgrade-mex-ic` | Convert C, C++, and Fortran MEX files from the separate complex API to the interleaved complex API with MX_HAS_INTERLEAVED_COMPLEX guards for SC/IC builds and performance verification. |

### MATLAB Programming ([`matlab-programming`](./matlab-programming/))

Write robust MATLAB functions with validated inputs

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-validate-function-arguments` | Validate MATLAB function inputs using arguments block. |

### MATLAB Software Development ([`matlab-software-development`](./matlab-software-development/))

Modernize legacy code, optimize performance and memory, document and create toolboxes, create projects, and develop build plans

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-instrument-opentelemetry-tracing` | Add OpenTelemetry tracing spans to MATLAB functions with correct context propagation and lifecycle. |
| `matlab-modernize-code` | Modernize deprecated MATLAB functions and patterns. |
| `matlab-optimize-memory` | Find and fix memory bottlenecks in MATLAB code using a structured measure-profile-optimize-verify workflow. |
| `matlab-optimize-performance` | Optimize performance of MATLAB code. |
| `matlab-package-toolbox` | Package MATLAB code as an installable .mltbx toolbox. |
| `matlab-write-help` | Generate or improve MATLAB help text following MathWorks documentation standards. |
| `matlab-write-performance-tests` | Write MATLAB performance tests using the matlab.perftest.TestCase framework. |

### Aerospace ([`aerospace`](./aerospace/))

Supports Aerospace Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | Compute aerospace environment properties (atmosphere, gravity, wind, magnetic field, geoid, space weather, ephemeris, Earth orientation) using Aerospace Toolbox functions. |
| `matlab-convert-aerospace-coordinates` | Convert aerospace coordinate frames, rotations, time, and units. |

### AI and Statistics ([`ai-and-statistics`](./ai-and-statistics/))

Supports Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, and Statistics and Machine Learning Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-classify-tabular-data` | Classify tabular data by comparing candidate models and identifying the statistically equivalent top tier. |
| `matlab-create-experiment` | Create experiments for the Experiment Manager app by analyzing user code, and generating the appropriate functions and hyperparameters. |
| `matlab-deploy-embedded-ai` | Deploy AI models to embedded hardware using MATLAB and Simulink. |
| `matlab-fit-curve` | Fit curves and surfaces interactively using the Curve Fitter app. |
| `matlab-import-external-ai-model` | Import PyTorch, ONNX, and Keras deep learning models into MATLAB and verify numerical correctness. |
| `matlab-train-network` | Train, evaluate, and export neural networks to Simulink using the recommended APIs. Migrate legacy neural network training code to modern replacements. |
| `matlab-use-machine-learning-apps` | Train, compare, and export machine learning models using Classification Learner and Regression Learner apps. |

### Automotive ([`automotive`](./automotive/))

Supports Automated Driving Toolbox&trade;, RoadRunner, and RoadRunner Scene Builder

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | Build Simulink models that co-simulate with Eclipse&trade; SUMO traffic simulator. |
| `matlab-import-driving-data` | Import recorded driving sensor data (GPS, camera, lidar, actor tracks) into scenariobuilder.* objects and synchronize, crop, offset, and normalize timestamps before scenario building. |
| `matlab-use-ncap-protocol` | Generate Euro NCAP test scenarios and variants, translate between simulators, and compute scores. |
| `matlab-use-scenario-builder` | Build driving scenes, scenarios, road surfaces, and 3D assets from recorded sensor data and export to RoadRunner, drivingScenario, OpenSCENARIO, OpenDRIVE, OpenCRG, or Unreal Engine&reg;. |
| `roadrunner-asset-mapping` | Generate RoadRunner asset path lookup tables for map format conversions in MATLAB. |
| `roadrunner-build-scenario-from-osc` | Interpret an OpenSCENARIO 1.x file and recreate the scenario programmatically in RoadRunner. |
| `roadrunner-convert-lanelet2-to-rrhd` | Convert Lanelet2 maps (.osm) to RoadRunner HD Map (.rrhd) format using MATLAB. |
| `roadrunner-core` | Connect to RoadRunner from MATLAB and manage project, scene, and scenario lifecycle. |
| `roadrunner-import-scene` | Connect to RoadRunner and import HD Map or OpenDRIVE files into a new scene using MATLAB. |
| `roadrunner-rrhd-authoring` | Build RoadRunner HD Map entities in MATLAB — lanes, boundaries, markings, junctions, signs, signals, barriers, parking. |
| `roadrunner-scenario-authoring` | Programmatically create RoadRunner driving scenarios from MATLAB. |
| `roadrunner-scenario-simulating` | Simulate RoadRunner scenarios programmatically via MATLAB and Simulink co-simulation. |

### Cloud Solutions ([`cloud-solutions`](./cloud-solutions/))

Supports MATLAB Drive&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-share-content` | Share MATLAB content by uploading to GitHub&reg;, MATLAB Drive, or File Exchange and generating "Open in MATLAB Online&trade;" URLs. |

### Code Generation ([`code-generation`](./code-generation/))

Supports Embedded Coder&trade;, Fixed-Point Designer&trade;, GPU Coder&trade;, and MATLAB Coder&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-deploy-ai-model` | Generate C/C++ or CUDA code from PyTorch ExportedProgram (.pt2) or LiteRT (.tflite) models using loadPyTorchExportedProgram, loadLiteRTModel, and codegen. Includes Simulink integration workflows. |
| `matlab-deploy-embedded-code` | Deploy MATLAB-generated code to embedded hardware with PIL verification. |
| `matlab-generate-code` | Generate, verify, and accelerate C/C++ or CUDA code from MATLAB using MATLAB Coder, Embedded Coder, or GPU Coder. |
| `matlab-optimize-gpu-codegen` | Optimize MATLAB functions for GPU Coder to generate faster CUDA code. |
| `matlab-review-fi-object-code` | Review MATLAB fixed-point (fi) code for performance, code generation efficiency, and correctness. |

### Computational Biology ([`computational-biology`](./computational-biology/))

Supports SimBiology&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-simbiology-model` | Build SimBiology models from scratch, modify existing ones, and generate diagram layouts. |
| `matlab-fit-simbiology-model` | Fit SimBiology model parameters to data. |
| `matlab-simulate-simbiology-model` | Run simulations, sweep parameters, explore what-if scenarios, and perform sensitivity analysis on SimBiology models. |

### Computational Finance ([`computational-finance`](./computational-finance/))

Supports Datafeed Toolbox&trade; and Spreadsheet Link&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-access-datafeed` | Connect to Bloomberg&reg;, FRED&reg;, and Haver Analytics&reg; to retrieve financial and economic data using the Datafeed Toolbox. |
| `matlab-use-spreadsheet-link` | Write VBA macros and worksheet functions for exchanging data with Excel using Spreadsheet Link. |

### Control Systems ([`control-systems`](./control-systems/))

Supports Predictive Maintenance Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-extract-battery-features` | Extract battery features from cycling test data for degradation and health analysis. |
| `matlab-extract-rotating-machinery-features` | Extract features from rotating machinery vibration data for condition monitoring and fault detection. |
| `matlab-identify-linear-system` | Identify linear dynamic models from measurement data using System Identification Toolbox&trade;. |

### Image Processing and Computer Vision ([`image-processing-and-computer-vision`](./image-processing-and-computer-vision/))

Supports Image Processing Toolbox&trade;, Computer Vision Toolbox&trade;, Lidar Toolbox&trade;, and Medical Imaging Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-spectral-images` | Read, process, analyze, label, and classify hyperspectral and multispectral images. |
| `matlab-display-image` | Display images and annotations for image processing, computer vision, and visual inspection. |
| `matlab-display-volume` | Display 3-D image volumes, medical image volumes, surface meshes, and annotations for 3-D image processing. |
| `matlab-integrate-pytorch-vision` | Create MATLAB interfaces to Python image processing and computer vision models from GitHub repositories or pip packages using MPyReq. |
| `matlab-model-optics` | Build, import, analyze, optimize, and tolerance optical systems and coatings using the Optical Design and Simulation Library. |
| `matlab-normalize-image` | Normalize images to [0,1] with proper validation for float-class, bit-depth mismatch, and indexed image edge cases. |
| `matlab-process-large-images` | Process large images using blockedImage. |
| `matlab-read-medical-data` | Read, write, and manipulate medical imaging data (DICOM, NIfTI, NRRD) using Image Processing Toolbox and Medical Imaging Toolbox APIs. |
| `matlab-read-write-point-cloud-file` | Read and write 3-D point cloud data in PLY, PCD, LAS/LAZ, PCAP, E57, and IDC formats. |
| `matlab-recognize-text` | Build OCR pipelines in MATLAB using the ocr() function. |
| `matlab-register-point-clouds` | Register and align 3-D point clouds using ICP, NDT, LOAM, FGR, phase correlation, and CPD algorithms. |

### Math and Optimization ([`math-and-optimization`](./math-and-optimization/))

Supports Optimization Toolbox&trade; and PDE Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-solve-optimization` | Formulate, solve, and validate MATLAB optimization problems using problem-based and solver-based approaches. |
| `matlab-solve-pde` | Build and solve finite element models for thermal, structural, and electromagnetic problems using PDE Toolbox. |

### Parallel Computing ([`parallel-computing`](./parallel-computing/))

Supports Parallel Computing Toolbox&trade; and MATLAB Parallel Server&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-diagnose-parfor` | Diagnose and fix parfor variable classification errors in MATLAB. |
| `matlab-discover-clusters` | Discover parallel computing clusters and manage cluster profiles. |
| `matlab-setup-gpu` | Detect and validate GPU availability for MATLAB GPU computing. |
| `matlab-set-up-worker-state` | Set up worker environment and per-worker state for parallel pools. |
| `matlab-use-thread-pool` | Speed up local parallel computing by using thread-based parallel pool. |

### Radar ([`radar`](./radar/))

Supports Phased Array System Toolbox&trade;, Sensor Fusion and Tracking Toolbox&trade;, and Mapping Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-design-radar-waveform` | Design, select, and analyze radar and sonar waveforms using the Phased Array System Toolbox. |
| `matlab-import-tracking-data` | Import raw tracking data (CSV, XLSX, TXT, or MATLAB tables) into objectDetection arrays and objectTrack arrays used by Sensor Fusion and Tracking Toolbox. |
| `matlab-simulate-radar-detections` | Simulate statistical radar detections for surveillance and tracking radar scenarios. |

### Reporting and Database Access ([`reporting-and-database-access`](./reporting-and-database-access/))

Supports Database Toolbox&trade;, MATLAB Report Generator&trade;, and Simulink Report Generator&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-connect-databricks` | Connect MATLAB to Databricks&reg; via Spark or JDBC for reading and writing data. |
| `matlab-generate-report` | Generate structured PDF, Word, and HTML reports from MATLAB data and Simulink models using the Report Generator API. |
| `matlab-use-database` | Read, write, update, and manage relational databases from MATLAB. |
| `matlab-use-duckdb` | Use DuckDB from MATLAB as a non-math operations engine on large tabular files and as a zero-config embedded database. Includes pre-flight routing, operations boundaries, and a profile-operate-close workflow. |

### RF and Mixed Signal ([`rf-and-mixed-signal`](./rf-and-mixed-signal/))

Supports Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Toolbox&trade;, RF PCB Toolbox&trade;, and SerDes Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | Measure phase noise, jitter, and timing from AMS simulation waveforms using Mixed-Signal Blockset. |
| `matlab-analyze-antenna-structures` | Design and analyze electrically large antenna structures — reflectors, reflectarrays, installed antennas on platforms, and radar cross section. |
| `matlab-analyze-em` | Compute S-parameters, insertion loss, fields, and currents for RF PCB performance validation. |
| `matlab-analyze-pcb-pdn` | Analyze PDN DC voltage and current distribution, IR drop, and design rule checking on PCB layouts. |
| `matlab-assemble-pcb-layout` | Build custom PCB structures with pcbComponent, shapes, Boolean operations, feeds, and multi-layer stackups. |
| `matlab-design-antenna` | Design antennas, arrays, and PCB antennas using MATLAB Antenna Toolbox. Covers catalog antenna design, custom antenna construction, PCB antenna design, finite and infinite arrays, AI-accelerated design exploration, and optimization. |
| `matlab-design-pcb-coupler` | Design Wilkinson, branchline, ratrace, and directional couplers, corporate dividers, and Rotman lenses. |
| `matlab-design-pcb-filter` | Design bandpass, lowpass, and bandstop RF filters using hairpin, coupled-line, combline, stub, and SIW topologies. |
| `matlab-design-pcb-passive` | Design spiral inductors, interdigital capacitors, baluns, resonators, and phase shifters for RF circuits. |
| `matlab-design-pcb-transmission-line` | Design microstrip, stripline, CPW, and differential pair transmission lines with impedance control and crosstalk analysis. |
| `matlab-export-session-script` | Export conversation MATLAB code to a clean, runnable .m script. |
| `matlab-integrate-antenna` | Integrate antennas into RF systems using MATLAB Antenna Toolbox and RF Toolbox. Covers impedance matching network design, measured antenna creation, RF propagation and site planning, and SAR estimation. |
| `matlab-integrate-pcb-circuit` | Cascade PCB components, add lumped elements, and export Touchstone files for multi-component RF circuits. |
| `matlab-manage-pcb-material` | Define dielectric substrates, metal conductors, multi-layer stackups, and loss models for RF PCB simulation. |
| `matlab-model-ams-systems` | Model PLL frequency synthesizers from IC datasheets or system specs using Mixed-Signal Blockset. Extracts parameters, selects architecture, assembles Simulink model, designs loop filter, validates phase noise. |
| `matlab-model-rf` | Design, analyze, and simulate RF systems in MATLAB using RF Toolbox and RF Blockset&trade; -- from S-parameter I/O through full Circuit Envelope time-domain simulation. |
| `matlab-model-serdes-systems` | Model, simulate, and optimize Serializer/Deserializer (SerDes) systems — serial and parallel links — using MATLAB SerDes Toolbox. |
| `matlab-model-via` | Model vias with pads, antipads, and ground return vias for high-speed PCB layer transitions. |
| `matlab-optimize-pcb-design` | Optimize RF PCB component dimensions for bandwidth, return loss, or area using patternsearch and surrogateopt. |
| `matlab-read-pcb-layout` | Import Gerber, ODB++, and Allegro .brd files and inspect nets, layers, shapes, and stackups. |
| `matlab-write-pcb-layout` | Export pcbComponent designs to Gerber files for PCB manufacturing. |

### Robotics and Autonomous Systems ([`robotics-and-autonomous-systems`](./robotics-and-autonomous-systems/))

Supports Navigation Toolbox&trade;, UAV Toolbox&trade;, and Robotics System Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-compute-gnss-position` | Computes multi-constellation Global Positioning System (GPS) or Global Navigation Satellite System (GNSS) positions from RINEX v3 data using rinexread, gnssmeasurements, receiverposition, and gnssoptions. |
| `matlab-connect-mavlink` | Establish MAVLink connections between MATLAB and PX4 or ArduPilot flight controllers. |
| `matlab-create-uav-scenario` | Create and simulate UAV scenarios with terrain, buildings, sensor-equipped platforms, and 3D visualization. |
| `matlab-fuse-inertial-sensors` | Analyzes sensor configurations and creates inertial fusion filters in MATLAB Navigation Toolbox. |
| `matlab-model-robot-kinematics` | Build manipulator models and validate kinematic solutions in MATLAB. |
| `matlab-plan-robot-motion` | Plan collision-free manipulator motion and generate time-parameterized trajectories. |

### Signal Processing ([`signal-processing`](./signal-processing/))

Supports Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Signal Processing Toolbox&trade;, and Wavelet Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-time-frequency-content` | Analyze time-frequency content using CWT, STFT, synchrosqueezing, and wavelet coherence. |
| `matlab-configure-scope-object` | Configure properties of scope-related Simulink blocks or MATLAB objects |
| `matlab-design-adaptive-filter` | Design and implement adaptive filters using System objects. |
| `matlab-design-digital-filter` | Design and validate digital filters in MATLAB. |
| `matlab-design-dsphdl-ddc` | Design HDL-optimized Digital Down Converters using dsphdl System objects. |
| `matlab-extract-signal-features` | Extract per-frame time, frequency, and time-frequency features from 1D signals. |
| `matlab-play-record-audio` | Play and record audio in MATLAB using audiostreamer. |
| `matlab-prepare-signal-data` | Condition raw signals (fill gaps, detrend, deoutlier, denoise, resample/align) and build signalDatastore pipelines for ML training -- labels, stratified splits, framing, parallel reads, and trainnet hand-off. |
| `matlab-process-streaming-audio` | Design and run real-time audio processing chains using Audio Toolbox streaming objects. |
| `matlab-write-audio-plugin` | Author Audio Toolbox plugins that compile to VST/AU via validateAudioPlugin and generateAudioPlugin. |

### Test and Measurement ([`test-and-measurement`](./test-and-measurement/))

Supports Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Industrial Communication Toolbox&trade;, MATLAB Support Package for Arduino Hardware&trade;, and Vehicle Network Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | Build industrial-grade SCADA/HMI dashboards in MATLAB following ISA-101 conventions. Produces a real App Designer app (.mlapp) by handing serialization to matlab-build-app when available, and falls back to a programmatic .m app otherwise. |
| `matlab-call-nidaqmx` | Translate NI-DAQmx C functions into correct calldaqlib MATLAB calls. |
| `matlab-connect-arduino` | Discover, configure, and connect to Arduino&reg; boards from MATLAB via USB. |
| `matlab-connect-bluetooth-low-energy-device` | Discover and connect to Bluetooth Low Energy peripheral devices from MATLAB. |
| `matlab-connect-opcua-client` | Discover OPC UA servers and create secure client connections in MATLAB. |
| `matlab-create-custom-arduino-library` | Create custom Arduino add-on libraries to access unsupported sensors and peripherals from MATLAB. |
| `matlab-discover-hardware` | Discover, inspect, and set up MATLAB-supported hardware devices via helper functions. |
| `matlab-enhance-camera-image` | Diagnose and enhance image quality from cameras connected via Image Acquisition Toolbox. |
| `matlab-find-pi-assets` | Find and query PI Data Archive tags and Asset Framework elements using piclient and afclient. |
| `matlab-import-export-vehicle-data` | Import, decode, and export vehicle network data from/to log files (ASC, BLF, MDF, DAT, TXT) with correct handling of polymorphic return types, CAN/CAN FD/LIN decode pipelines, and MDF/BLF writing workflows. |
| `matlab-modernize-daq` | Port legacy session-based Data Acquisition Toolbox code to the modern DataAcquisition interface. |
| `matlab-use-cameras` | Connect to and acquire images from cameras using Image Acquisition Toolbox videoinput interface. |
| `matlab-use-vehicle-network` | Set up, troubleshoot, and analyze CAN/CAN FD vehicle network communication in MATLAB using Vehicle Network Toolbox across all supported hardware vendors. |

### Wireless Communications ([`wireless-communications`](./wireless-communications/))

Supports Communications Toolbox&trade;, 5G Toolbox&trade;, WLAN Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, and Wireless Testbench&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-add-awgn` | Add Additive White Gaussian Noise (AWGN) noise and convert between SNR, Eb/No, Es/No, and per-subcarrier SNR for communications simulations. |
| `matlab-design-ofdm-system` | Design and simulate custom OFDM systems using ofdmmod/ofdmdemod, with fading channel configuration, equalization, synchronization (timing/CFO), LDPC coding, SNR handling, subcarrier allocation, and pilot-based channel estimation |
| `matlab-generate-5g-waveform` | Generate 3GPP-compliant 5G NR downlink and uplink baseband waveforms. |
| `matlab-generate-ble-waveform` | Generate and analyze Bluetooth Low Energy PHY waveforms. |
| `matlab-generate-gnss-waveform` | Generate GNSS baseband waveforms (GPS, Galileo, NavIC) with physically realistic or user-specified channel impairments using the Satellite Communications Toolbox. |
| `matlab-generate-wlan-waveform` | Generate standard-compliant IEEE 802.11 WLAN waveforms. |
| `matlab-set-up-usrp-radio` | Set up and verify NI USRP radios for use with Wireless Testbench. |
| `matlab-simulate-bluetooth-network` | Simulate Bluetooth system-level networks including BLE, Classic BR/EDR, and LE Audio. |
| `matlab-simulate-wireless-network` | Set up and run wireless network simulations using wirelessNetworkSimulator. |
| `matlab-transmit-capture-usrp` | Transmit and capture RF waveforms using Wireless Testbench with NI USRP radios. |

<!-- END SKILLS -->

## How Skills Are Installed

For details on how these skills are installed, see
[Install MATLAB Agentic Toolkit](../README.md#install-matlab-agentic-toolkit)

----

Copyright 2026 The MathWorks, Inc.

----
