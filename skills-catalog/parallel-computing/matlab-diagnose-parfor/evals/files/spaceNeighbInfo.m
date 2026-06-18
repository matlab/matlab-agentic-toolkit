NJ = 4;
StatesMat = randi(10, 50, 4);

myInfo = cell(length(StatesMat), 4);
parfor ii = 1:length(StatesMat)
    [neigbStates, neigbStatesIdx, ~, mRNeigb] = ...
        localNeighborStates(NJ, StatesMat, StatesMat(ii,:));
    myInfo{ii,1} = neigbStates;
    myInfo{ii,2} = neigbStatesIdx;
    myInfo{ii,4} = mRNeigb;
end
% Copyright 2026 The MathWorks, Inc.
