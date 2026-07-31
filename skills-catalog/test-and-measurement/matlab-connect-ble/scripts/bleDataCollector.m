function bleDataCollector(bleObj, serviceID, characteristicID, duration, filename)
%bleDataCollector Log BLE characteristic notification data to a text file.
%   bleDataCollector(bleObj, serviceID, characteristicID, duration, filename)
%   subscribes to notifications on the specified characteristic, logs each
%   notification's timestamp and raw byte values to a tab-separated text
%   file for the given duration, then unsubscribes and closes the file.
%
%   The output file has one row per notification:
%       timestamp<TAB>byte1 byte2 byte3 ...
%
%   Example:
%       b = ble("HeartSensor");
%       bleDataCollector(b, "180D", "2A37", 10, "heartRateLog.txt")
%
%   See also ble, characteristic, subscribe, unsubscribe

    arguments
        bleObj (1,1)
        serviceID (1,1) string
        characteristicID (1,1) string
        duration (1,1) double {mustBePositive} = 10
        filename (1,1) string = "bleLog.txt"
    end

    charObj = characteristic(bleObj, serviceID, characteristicID);
    fileID = fopen(filename, "w+");
    if fileID == -1
        error("bleDataCollector:fileOpen", "Cannot open file: %s", filename);
    end

    charObj.DataAvailableFcn = @(src, ~) logNotification(src, fileID);
    subscribe(charObj);
    fprintf("Logging BLE data to %s for %d seconds...\n", filename, duration);
    pause(duration);
    unsubscribe(charObj);
    charObj.DataAvailableFcn = [];
    fclose(fileID);
    fprintf("Done. File saved: %s\n", filename);
end

function logNotification(src, fileID)
%logNotification Callback that reads buffered notification and writes to file.
    [data, timestamp] = read(src, "oldest");
    timestamp.Format = "yyyy-MM-dd HH:mm:ss.SSSS";
    fprintf(fileID, "%s\t", timestamp);
    fprintf(fileID, repmat('%d ', 1, length(data)), data);
    fprintf(fileID, "\n");
end
% Copyright 2026 The MathWorks, Inc.
