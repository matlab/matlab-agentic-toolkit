# Time-Domain Analysis

For time-domain channel characterization (TDR, impulse response, step response, eye diagrams), fit the extracted S-parameters with a rational model, then compute time responses. See the `matlab-fit-rational-model` skill for full details.

## End-to-End: .s4p Connector + Trace + Via → Step Response

```matlab
% Load 4-port connector, build channel, fit, compute step response -- all in one
sConn = sparameters('connector.s4p');
Z0 = sConn.Impedance;
np = nport(sConn); np.Name = 'ConnIn';

trace = txlineWRLGC;
trace.Lo = 350e-9; trace.Co = 130e-12;
trace.Ro = 2; trace.Rs = 5e-4; trace.Gd = 1e-11;
trace.LineLength = 0.1; trace.Name = 'PCBTrace';

via = circuit('Via');
add(via, [1 2], inductor(0.5e-9, 'Lvia'));
add(via, [2 0], capacitor(0.1e-12, 'Cvia'));
setports(via, [1 0], [2 0]);

% Alternative: extract 2-port from 4-port first, then use as 2-port nport
%   s2p = snp2smp(sConn, [1 3]);  % snp2smp(sparametersObj, portIndices)
%   conn2p = nport(s2p); conn2p.Name = 'Conn';
%   add(ckt, [1 2 0 0], conn2p);  % simpler 2-port node mapping
%
% Or use 4-port directly in circuit: through-path = port1(node1)->port3(node3)
ckt = circuit('Channel');
add(ckt, [1 2 3 4 0 0 0 0], np);
add(ckt, [2 0], resistor(Z0, 'Term2'));   % terminate port 2
add(ckt, [4 0], resistor(Z0, 'Term4'));   % terminate port 4
add(ckt, [3 5 0 0], trace);              % trace from conn port3 output
add(ckt, [5 6 0 0], via);
npOut = nport(sparameters('connector.s4p')); npOut.Name = 'ConnOut';
add(ckt, [6 7 8 9 0 0 0 0], npOut);      % 2nd connector: port1=node6
add(ckt, [7 0], resistor(Z0, 'Term7'));   % terminate port 2
add(ckt, [9 0], resistor(Z0, 'Term9'));   % terminate port 4
setports(ckt, [1 0], [8 0]);             % output = port3 of 2nd conn (node 8)

freq = linspace(1e8, 20e9, 500);
s = sparameters(ckt, freq);
rfplot(s, 2, 1); title('Channel S21');

% Fit S21 and compute step response (single-param fit -> plain vectors)
s21 = rfparam(s, 2, 1);
[fit21, errdb] = rational(s.Frequencies, s21);
[resp, t] = stepresp(fit21, 1e-12, 10000, 50e-12);
figure; plot(t*1e9, resp);
xlabel('Time (ns)'); ylabel('Voltage'); title('Channel Step Response');
fprintf('Fit: %d poles, %.1f dB error\n', fit21.NumPoles, errdb);
```

**Key points for single-param fit:** `rational(freq, s21)` returns a scalar fit. Its `stepresp`/`impulse` return **plain vectors** (not cell arrays). Cell arrays `{i,j}` are only returned when fitting the entire `sparameters` object with `rational(s)`.

## Synthetic .s4p Test Data

When no physical Touchstone file is available, create synthetic S-parameter data programmatically:

```matlab
% Create a realistic 4-port connector model (through + isolation)
freq = linspace(1e8, 20e9, 200)';
nF = numel(freq);
loss = 0.03;
phase = reshape(exp(-1j*2*pi*freq*0.2e-9), 1, 1, []);
S = 0.05*eye(4) + ...
    [0 0 1-loss 0; 0 0 0 (1-loss); (1-loss) 0 0 0; 0 (1-loss) 0 0].*phase;
sConn = sparameters(S, freq);
outFile = 'connector.s4p';
rfwrite(sConn, outFile, 'ForceOverwrite', true);
```

----

Copyright 2026 The MathWorks, Inc.

----
