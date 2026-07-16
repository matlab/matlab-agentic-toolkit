# Skills Catalog

The skills catalog organizes agent skills into groups. Each group contains one or more skill folders, each with a `SKILL.md` file and a `manifest.yaml` file. The `manifest.yaml` file contains metadata about the skill.

## Skills

<!-- BEGIN SKILLS -->
### MATLAB Core ([`matlab-core`](./matlab-core/))

Create, debug, test, review, and manage MATLAB&reg; code and installations

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-create-live-script` | Create plain-text MATLAB Live Scripts with rich text, LaTeX equations, and inline figures. |
| `matlab-debugging` | Diagnose MATLAB errors and unexpected behavior. |
| `matlab-install-products` | Install MathWorks&reg; products from the command line using MATLAB Package Manager (mpm). |
| `matlab-list-products` | Show all installed MATLAB products and support packages for a given MATLAB installation folder. |
| `matlab-read-doc` | Fetch and navigate MathWorks documentation specific for your MATLAB release to determine correct function syntax, complete workflows, and determine best practices for working in MATLAB and Simulink&reg; software. |
| `matlab-review-code` | Review MATLAB code for quality, performance, maintainability, and adherence to MathWorks coding standards. |
| `matlab-testing` | Generate and run MATLAB unit tests using the matlab.unittest framework. |

### MATLAB App Building ([`matlab-app-building`](./matlab-app-building/))

Build MATLAB apps programmatically using UI components, layouts, callbacks, and web integration

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-app` | Build MATLAB apps with guided path selection, layout archetypes, and structured implementation plans. |
| `matlab-build-chart` | Create and customize MATLAB charts with correct axes handling, modern layout, annotations, interactivity, and animation patterns. |
| `matlab-theming` | Apply color palettes, brand theming, dark mode, and conditional styling to MATLAB charts and uifigure apps. |

### MATLAB Data Import and Analysis ([`matlab-data-import-and-analysis`](./matlab-data-import-and-analysis/))

Analyze tabular data in MATLAB using tables, timetables, filtering, aggregation, and time-series operations

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-data` | Analyze data in MATLAB using tables, timetables, numeric arrays, and gridded data — filtering, aggregation, smoothing, cleaning, and time-series operations. |
| `matlab-choose-bigdata-solution` | Choose the right MATLAB tool for processing large tabular data that may not fit in memory. |

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
| `matlab-analyze-dependencies` | Analyze toolbox dependencies. |
| `matlab-assess-toolbox` | Assess toolbox readiness for packaging. Validates help text, tests, coverage, code issues, dependencies, and function signatures. |
| `matlab-build-toolbox` | Build a MATLAB toolbox package with build tool. |
| `matlab-create-buildfile` | Generate a buildfile.m for preparing and packaging a toolbox. |
| `matlab-create-project` | Create a MATLAB project from an existing folder of code. |
| `matlab-define-toolbox-api` | Define toolbox scope and public API from a folder of code. |
| `matlab-document-toolbox` | Generate toolbox documentation including README, examples, and functionSignatures.json. |
| `matlab-exclude-files` | Generate a toolbox.ignore file to exclude files from packaging. |
| `matlab-instrument-opentelemetry-tracing` | Add OpenTelemetry tracing spans to MATLAB functions with correct context propagation and lifecycle. |
| `matlab-modernize-code` | Modernize deprecated MATLAB functions and patterns. |
| `matlab-optimize-memory` | Find and fix memory bottlenecks in MATLAB code using a structured measure-profile-optimize-verify workflow. |
| `matlab-optimize-performance` | Optimize performance of MATLAB code. |
| `matlab-publish-toolbox` | Version-stamp and publish a MATLAB toolbox package. |
| `matlab-write-help` | Generate or improve MATLAB help text following MathWorks documentation standards. |
| `matlab-write-performance-tests` | Write MATLAB performance tests using the matlab.perftest.TestCase framework. |

### Aerospace ([`aerospace`](./aerospace/))

Supports Aerospace Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | Compute aerospace environment properties (atmosphere, gravity, wind, magnetic field, geoid, space weather, ephemeris, Earth orientation) using Aerospace Toolbox functions. |
| `matlab-convert-aerospace-coordinates` | Convert between aerospace coordinate frames, rotation representations, time systems, and unit systems using Aerospace Toolbox. |

### AI and Statistics ([`ai-and-statistics`](./ai-and-statistics/))

Supports Deep Learning Toolbox&trade; and Statistics and Machine Learning Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-create-experiment` | Create experiments for the Experiment Manager app by analyzing user code, and generating the appropriate functions and hyperparameters. |
| `matlab-deploy-embedded-ai` | Deploy AI models to embedded hardware using MATLAB and Simulink. |
| `matlab-import-external-ai-model` | Import PyTorch, ONNX, and Keras deep learning models into MATLAB and verify numerical correctness. |
| `matlab-train-network` | Train, evaluate, and export neural networks to Simulink using the recommended APIs. Migrate legacy neural network training code to modern replacements. |
| `matlab-use-machine-learning-apps` | Train, compare, and export machine learning models using Classification Learner and Regression Learner apps. |

### Automotive ([`automotive`](./automotive/))

Supports Automated Driving Toolbox&trade;, RoadRunner, and RoadRunner Scene Builder

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | Build Simulink models that co-simulate with Eclipse&trade; SUMO traffic simulator. |
| `matlab-driving-data-importer` | Import recorded driving sensor data (GPS, camera, lidar, actor tracks) into scenariobuilder.* objects and synchronize, crop, offset, and normalize timestamps before scenario building. |
| `matlab-ncap-testing` | Generate Euro NCAP test scenarios and variants, translate between simulators, and compute scores. |
| `matlab-scenario-builder` | Build driving scenes, scenarios, road surfaces, and 3D assets from recorded sensor data and export to RoadRunner, drivingScenario, OpenSCENARIO, OpenDRIVE, OpenCRG, or Unreal Engine&reg;. |
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
| `matlab-sharing` | Share MATLAB content by uploading to GitHub&reg;, MATLAB Drive, or File Exchange and generating "Open in MATLAB Online&trade;" URLs. |

### Code Generation ([`code-generation`](./code-generation/))

Supports Fixed-Point Designer&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-deploy-ai-model` | Generate C/C++ or CUDA code from PyTorch ExportedProgram models using loadPyTorchExportedProgram and codegen. |
| `matlab-deploy-embedded-code` | Deploy MATLAB-generated code to embedded hardware with PIL verification. |
| `matlab-review-fi-code` | Review MATLAB fixed-point (fi) code for performance, code generation efficiency, and correctness. |

### Computational Biology ([`computational-biology`](./computational-biology/))

Supports SimBiology&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-simbiology-model` | Build SimBiology models from scratch, modify existing ones, and generate diagram layouts. |
| `matlab-fit-simbiology-model` | Fit SimBiology model parameters to data. |
| `matlab-simulate-simbiology-model` | Run simulations, sweep parameters, explore what-if scenarios, and perform sensitivity analysis on SimBiology models. |

### Computational Finance ([`computational-finance`](./computational-finance/))

Supports Datafeed Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-access-datafeed` | Connect to Bloomberg&reg;, FRED&reg;, and Haver Analytics&reg; to retrieve financial and economic data using the Datafeed Toolbox. |

### Image Processing and Computer Vision ([`image-processing-and-computer-vision`](./image-processing-and-computer-vision/))

Supports Image Processing Toolbox&trade;, Computer Vision Toolbox&trade;, Lidar Toolbox&trade;, and Medical Imaging Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-display-image` | Display images and annotations for image processing, computer vision, and visual inspection. |
| `matlab-display-volume` | Display 3-D image volumes, medical image volumes, surface meshes, and annotations for 3-D image processing. |
| `matlab-integrate-pytorch-vision` | Create MATLAB interfaces to Python image processing and computer vision models from GitHub repositories or pip packages using MPyReq. |
| `matlab-model-optics` | Build, import, analyze, optimize, and tolerance optical systems and coatings using the Optical Design and Simulation Library. |
| `matlab-ocr` | Build OCR pipelines in MATLAB using the ocr() function. |
| `matlab-point-cloud-file-io` | Read and write 3-D point cloud data in PLY, PCD, LAS/LAZ, PCAP, E57, and IDC formats. |
| `matlab-point-cloud-registration` | Register and align 3-D point clouds using ICP, NDT, LOAM, FGR, phase correlation, and CPD algorithms. |
| `matlab-process-large-images` | Process large images using blockedImage. |
| `matlab-read-medical-data` | Read, write, and manipulate medical imaging data (DICOM, NIfTI, NRRD) using Image Processing Toolbox and Medical Imaging Toolbox APIs. |

### Math and Optimization ([`math-and-optimization`](./math-and-optimization/))

Supports PDE Toolbox&trade;

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
| `matlab-setup-worker-state` | Set up worker environment and per-worker state for parallel pools. |
| `matlab-use-thread-pool` | Speed up local parallel computing by using thread-based parallel pool. |

### Radar ([`radar`](./radar/))

Supports Phased Array System Toolbox&trade;, Sensor Fusion and Tracking Toolbox&trade;, and Mapping Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-design-radar-waveform` | Design and analyze radar and sonar waveforms using Phased Array System Toolbox. |
| `matlab-import-tracking-data` | Import ground truth trajectory data for use with Sensor Fusion and Tracking Toolbox. |
| `matlab-simulate-radar-detections` | Simulate statistical radar detections for surveillance and tracking radar scenarios. |

### Reporting and Database Access ([`reporting-and-database-access`](./reporting-and-database-access/))

Supports Database Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-connect-databricks-jdbc` | Connect MATLAB to Databricks&reg; using JDBC drivers via Database Toolbox. |
| `matlab-connect-databricks-spark` | Connect MATLAB to Databricks via Spark and read large tables with server-side filtering. |
| `matlab-generate-report` | Generate structured PDF, Word, and HTML reports from MATLAB data and Simulink models using the Report Generator API. |
| `matlab-map-database-objects` | Generate MATLAB Object Relational Mapping (ORM) code using Database Toolbox. |
| `matlab-read-database` | Read data from relational databases using MATLAB Database Toolbox. |
| `matlab-use-duckdb` | Use DuckDB from MATLAB as a non-math operations engine on large tabular files and as a zero-config embedded database. Includes pre-flight routing, operations boundaries, and a profile-operate-close workflow. |
| `matlab-write-database` | Write data to relational databases and perform database operations from MATLAB. |

### RF and Mixed Signal ([`rf-and-mixed-signal`](./rf-and-mixed-signal/))

Supports Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Toolbox&trade;, RF PCB Toolbox&trade;, and SerDes Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | Measure phase noise, jitter, and timing from AMS simulation waveforms using Mixed-Signal Blockset. |
| `matlab-analyze-em` | Compute S-parameters, insertion loss, fields, and currents for RF PCB performance validation. |
| `matlab-analyze-installed-antenna` | Analyze antennas installed on electrically large conducting platforms such as vehicles and aircraft. |
| `matlab-analyze-pcb-pdn` | Analyze PDN DC voltage and current distribution, IR drop, and design rule checking on PCB layouts. |
| `matlab-analyze-rcs` | Compute and visualize monostatic and bistatic radar cross section of antennas and platforms. |
| `matlab-analyze-rf-propagation` | Analyze RF propagation and plan wireless sites using coverage maps, ray tracing, and path loss models. |
| `matlab-assemble-pcb-layout` | Build custom PCB structures with pcbComponent, shapes, Boolean operations, feeds, and multi-layer stackups. |
| `matlab-create-ai-antenna` | Explore antenna design space and reconstruct 3D radiation patterns using AI surrogate models. |
| `matlab-create-custom-antenna` | Build custom antennas from geometric primitives using Antenna Toolbox customAntenna. |
| `matlab-create-measured-antenna` | Create measuredAntenna objects from simulated or measured data for site planning and satellite links. |
| `matlab-design-antenna` | Design and analyze antennas at a target frequency using MATLAB Antenna Toolbox. |
| `matlab-design-antenna-matching-network` | Design impedance matching networks for antennas using RF Toolbox matchingnetwork. |
| `matlab-design-array` | Design and analyze finite and infinite antenna arrays with beam steering, tapering, and scan impedance. |
| `matlab-design-pcb-antenna` | Design multi-layer PCB antennas with custom metal patterns, feeds, and Gerber export using pcbStack. |
| `matlab-design-pcb-coupler` | Design Wilkinson, branchline, ratrace, and directional couplers, corporate dividers, and Rotman lenses. |
| `matlab-design-pcb-filter` | Design bandpass, lowpass, and bandstop RF filters using hairpin, coupled-line, combline, stub, and SIW topologies. |
| `matlab-design-pcb-passive` | Design spiral inductors, interdigital capacitors, baluns, resonators, and phase shifters for RF circuits. |
| `matlab-design-pcb-txline` | Design microstrip, stripline, CPW, and differential pair transmission lines with impedance control and crosstalk analysis. |
| `matlab-design-reflectarray` | Design reflectarray antennas and reconfigurable intelligent surfaces with phase-controlled unit cells. |
| `matlab-design-reflector-antenna` | Design and analyze parabolic, Cassegrain, Gregorian, and corner reflector antennas. |
| `matlab-estimate-sar` | Estimate Specific Absorption Rate from antennas near or inside biological tissue. |
| `matlab-export-session-script` | Export conversation MATLAB code to a clean, runnable .m script. |
| `matlab-integrate-pcb-circuit` | Cascade PCB components, add lumped elements, and export Touchstone files for multi-component RF circuits. |
| `matlab-manage-pcb-material` | Define dielectric substrates, metal conductors, multi-layer stackups, and loss models for RF PCB simulation. |
| `matlab-model-ams-systems` | Model PLL frequency synthesizers from IC datasheets or system specs using Mixed-Signal Blockset. Extracts parameters, selects architecture, assembles Simulink model, designs loop filter, validates phase noise. |
| `matlab-model-rf` | Design, analyze, and simulate RF systems in MATLAB using RF Toolbox and RF Blockset&trade; -- from S-parameter I/O through full Circuit Envelope time-domain simulation. |
| `matlab-model-serdes-systems` | Model, simulate, and optimize Serializer/Deserializer (SerDes) systems — serial and parallel links — using MATLAB SerDes Toolbox. |
| `matlab-model-via` | Model vias with pads, antipads, and ground return vias for high-speed PCB layer transitions. |
| `matlab-optimize-antenna` | Optimize antenna and array designs using SADEA and TR-SADEA surrogate-assisted algorithms. |
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
| `matlab-analyze-signal-cwt` | Analyze signals using the Continuous Wavelet Transform. |
| `matlab-configure-scope-object` | Configure properties of scope-related Simulink blocks or MATLAB objects |
| `matlab-design-adaptive-filter` | Design and implement adaptive filters using System objects. |
| `matlab-design-digital-filter` | Design and validate digital filters in MATLAB. |
| `matlab-dsphdl-ddc-design` | Design HDL-optimized Digital Down Converters using dsphdl System objects. |
| `matlab-extract-signal-features` | Extract per-frame time, frequency, and time-frequency features from 1D signals. |
| `matlab-play-record-audio` | Play and record audio in MATLAB using audiostreamer. |
| `matlab-prepare-signal-data` | Build signalDatastore pipelines for ML training -- labels, stratified splits, framing, parallel reads, and trainnet hand-off. |
| `matlab-write-audio-plugin` | Author Audio Toolbox plugins that compile to VST/AU via validateAudioPlugin and generateAudioPlugin. |

### Test and Measurement ([`test-and-measurement`](./test-and-measurement/))

Supports Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Industrial Communication Toolbox&trade;, MATLAB Support Package for Arduino Hardware&trade;, and Vehicle Network Toolbox&trade;

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | Build industrial-grade SCADA/HMI dashboards in MATLAB App Designer following ISA-101 conventions. |
| `matlab-call-nidaqmx` | Translate NI-DAQmx C functions into correct calldaqlib MATLAB calls. |
| `matlab-connect-arduino` | Discover, configure, and connect to Arduino&reg; boards from MATLAB via USB. |
| `matlab-connect-opcua-client` | Discover OPC UA servers and create secure client connections in MATLAB. |
| `matlab-create-custom-arduino-library` | Create custom Arduino add-on libraries to access unsupported sensors and peripherals from MATLAB. |
| `matlab-discover-hardware` | Discover, inspect, and set up MATLAB-supported hardware devices via helper functions. |
| `matlab-enhance-camera-image` | Diagnose and enhance image quality from cameras connected via Image Acquisition Toolbox. |
| `matlab-find-pi-assets` | Find and query PI Data Archive tags and Asset Framework elements using piclient and afclient. |
| `matlab-import-vehicle-data` | Import and decode vehicle network data from log files (ASC, BLF, MDF, DAT, TXT) with correct handling of polymorphic return types and CAN/CAN FD/LIN decode pipelines. |
| `matlab-modernize-daq` | Port legacy session-based Data Acquisition Toolbox code to the modern DataAcquisition interface. |
| `matlab-use-cameras` | Connect to and acquire images from cameras using Image Acquisition Toolbox videoinput interface. |
| `matlab-vehicle-network-communication` | Set up and manage CAN/CAN FD vehicle network communication in MATLAB using Vehicle Network Toolbox across all supported hardware vendors. |

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

<!-- END SKILLS -->

## How Skills Are Installed

For details on how these skills are installed, see
[Install MATLAB Agentic Toolkit](../README.md#install-matlab-agentic-toolkit)

----

Copyright 2026 The MathWorks, Inc.

----
