% Copyright 2026 The MathWorks, Inc.
classdef SignalBuffer < handle
    properties
        SampleRate (1,1) double = 44100
        Data (:,1) double = []
        Label (1,1) string = ""
    end
    methods
        function obj = SignalBuffer(data, sampleRate)
            arguments
                data (:,1) double
                sampleRate (1,1) double = 44100
            end
            obj.Data = data;
            obj.SampleRate = sampleRate;
        end
        function trimmed = trim(obj, startSample, endSample)
            trimmed = obj.Data(startSample:endSample);
        end
        function duration = getDuration(obj)
            duration = numel(obj.Data) / obj.SampleRate;
        end
    end
    methods (Access = private)
        function validateIndex(obj, idx)
            assert(idx <= numel(obj.Data));
        end
    end
end
