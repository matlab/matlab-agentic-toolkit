function [comp, speciesHandles] = addAndPositionCompartment(model, compName, capacity, compPosition, speciesInfo, options)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% ADDANDPOSITIONCOMPARTMENT Create a compartment with species and position everything in one call.
%
%   [comp, speciesHandles] = addAndPositionCompartment(model, compName, capacity, compPosition, speciesInfo)
%   [comp, sp] = addAndPositionCompartment(__, 'FontWeight', 'normal', 'AutoExpand', false)
%
%   This function atomically creates a compartment, adds its species, opens
%   the Builder if needed, and positions everything — preventing the overlap
%   errors that occur when creation and positioning are separated.
%
%   Inputs:
%     model        - SimBiology model object (not a UUID string)
%     compName     - Name for the new compartment (char)
%     capacity     - Compartment capacity (numeric)
%     compPosition - [x y w h] position for the compartment
%     speciesInfo  - Cell array of structs with fields:
%                      .Name           - Species name (char)
%                      .Value  - Initial value (numeric)
%                      .Position       - [x y w h] or [x y] position for the species block.
%                                        If [x y] (2 elements), width is auto-computed from
%                                        name length (length*10+20) and height defaults to 16.
%                    OR an empty cell {} if no species yet.
%
%   Name-Value Options:
%     FontWeight       - Font weight for compartment and species labels ('bold')
%     TextLocation     - Text location for species labels ('center')
%     Padding          - Minimum padding from compartment edge in pixels (20)
%     AutoExpand       - Auto-expand compartment to fit species (true)
%     AutoFixPositions - Auto-correct species positions that fall outside compartment (true)
%
%   Outputs:
%     comp           - Handle to the new compartment
%     speciesHandles - SimBiology Species ARRAY (NOT a cell array).
%                      Index with sp(1), sp(2), etc. — NOT sp{1}, sp{2}.
%
%   Example:
%     model = sbiomodel('MyModel');
%     specInfo = { ...
%       struct('Name','Drug','Value',100,'Position',[75 82 50 16]), ...
%       struct('Name','Metabolite','Value',0,'Position',[75 102 100 16]) ...
%     };
%     [comp, sp] = addAndPositionCompartment(model, 'Central', 1, [50 50 200 150], specInfo);
%
%     % Override styling defaults:
%     [comp, sp] = addAndPositionCompartment(model, 'Tumor', 1, [300 50 200 150], {}, ...
%         'FontWeight', 'normal', 'AutoExpand', false);
%
%   See also: addcompartment, addspecies, openLiveBuilder

    arguments
        model
        compName
        capacity
        compPosition
        speciesInfo
        options.FontWeight (1,1) string {mustBeMember(options.FontWeight, ["plain","bold","italic","bold italic"])} = "bold"
        options.TextLocation (1,1) string {mustBeMember(options.TextLocation, ["center","left","right","top","bottom"])} = "center"
        options.Padding (1,1) double = 20
        options.AutoExpand (1,1) logical = true
        options.AutoFixPositions (1,1) logical = true
    end

    % Create compartment and species FIRST (before diagram calls)
    comp = addcompartment(model, compName, capacity);
    nSpecies = numel(speciesInfo);
    if nSpecies > 0
        s = speciesInfo{1};
        speciesHandles = addspecies(comp, s.Name, s.Value);
        for i = 2:nSpecies
            s = speciesInfo{i};
            speciesHandles(i) = addspecies(comp, s.Name, s.Value);
        end
    else
        speciesHandles = [];
    end

    % Ensure Builder is open and diagram is ready for THIS model.
    % Always verify by testing a getBlock call — isAppOpen alone is not
    % sufficient because the Builder may be open for a different model.
    diagramReady = false;
    try
        simbio.diagram.getBlock(comp, 'Position');
        diagramReady = true;
    catch
    end
    if ~diagramReady
        openLiveBuilder(model);
    end

    % Pre-validate: ensure compartment is wide/tall enough for all species
    % If not, auto-expand the compartment before positioning
    cx = compPosition(1); cy = compPosition(2);
    cw = compPosition(3); ch = compPosition(4);
    pad = options.Padding;
    if options.AutoExpand
        minW = cw; minH = ch;
        for i = 1:nSpecies
            pos = speciesInfo{i}.Position;
            if numel(pos) == 2
                w = length(speciesInfo{i}.Name) * 10 + 20;
                pos = [pos(1) pos(2) w 16];
                speciesInfo{i}.Position = pos;
            end
            % Check if species width exceeds compartment width
            neededW = pos(3) + 2*pad;
            if neededW > minW
                minW = neededW;
            end
        end
        if nSpecies > 0
            % Ensure height fits all species stacked vertically
            neededH = nSpecies * 16 + (nSpecies + 1) * pad;
            if neededH > minH
                minH = neededH;
            end
        end
        if minW > cw || minH > ch
            compPosition = [cx cy minW minH];
            cw = minW; ch = minH;
            fprintf('  Auto-expanded %s to [%d %d %d %d] to fit species\n', ...
                compName, cx, cy, cw, ch);
        end
    end

    % Position compartment FIRST (this auto-moves child species)
    % Retry with backoff — diagram may not be ready immediately after opening
    for attempt = 1:5
        try
            simbio.diagram.setBlock(comp, 'Position', compPosition);
            break;
        catch ME
            if attempt == 5
                rethrow(ME);
            end
            pause(1);
        end
    end

    for i = 1:nSpecies
        pos = speciesInfo{i}.Position;
        if numel(pos) == 2
            % Auto-compute width from name length
            w = length(speciesInfo{i}.Name) * 10 + 20;
            pos = [pos(1) pos(2) w 16];
        end

        if options.AutoFixPositions
            % Validate: species must fit inside compartment with padding
            spRight  = pos(1) + pos(3);
            spBottom = pos(2) + pos(4);
            valid = pos(1) >= cx + pad && ...
                    pos(2) >= cy + pad && ...
                    spRight  <= cx + cw - pad && ...
                    spBottom <= cy + ch - pad;

            if ~valid
                % Auto-fix: center species horizontally, place at valid y
                w = pos(3);
                h = pos(4);
                fixedX = round(cx + cw/2 - w/2);
                % Use requested y if valid, otherwise distribute vertically
                if pos(2) >= cy + pad && spBottom <= cy + ch - pad
                    fixedY = pos(2);
                else
                    fixedY = round(cy + pad + (i-1) * (ch - 2*pad - h) / max(nSpecies - 1, 1));
                end
                pos = [fixedX fixedY w h];
                fprintf('  Auto-fixed %s position to [%d %d %d %d] (valid range: x=[%d..%d], y=[%d..%d])\n', ...
                    speciesInfo{i}.Name, pos(1), pos(2), pos(3), pos(4), ...
                    cx+pad, cx+cw-pad-w, cy+pad, cy+ch-pad-h);
            end
        end

        simbio.diagram.setBlock(speciesHandles(i), 'Position', pos);
    end

    % Apply styling (best-effort — don't fail the whole operation)
    try
        simbio.diagram.setBlock(comp, 'FontWeight', options.FontWeight);
        for i = 1:nSpecies
            simbio.diagram.setBlock(speciesHandles(i), 'TextLocation', options.TextLocation);
            simbio.diagram.setBlock(speciesHandles(i), 'FontWeight', options.FontWeight);
        end
    catch
    end
end

% Copyright 2026 The MathWorks, Inc.
