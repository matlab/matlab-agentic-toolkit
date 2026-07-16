# Image Data Conversion Patterns

## MATLAB image to Python tensor (basic)

```matlab
inp = im2single(im);
% Ensure 3-channel RGB
if ismatrix(inp)
    inp = repmat(inp, [1 1 3]);
end
% Resize if needed
inp = imresize(inp, [H W]);
% Reshape to NCHW format for PyTorch: [batch, channels, height, width]
inp = reshape(inp, [1 size(inp)]);
inp = permute(inp, [1 4 2 3]);
inp = py.torch.tensor(inp).to("cuda");
```

## MATLAB image to Python tensor (with ImageNet normalization + center crop)

Many vision models (DINOv2, ResNet, ViT, etc.) expect ImageNet-normalized input:

```matlab
inp = im2single(im);
if ismatrix(inp)
    inp = repmat(inp, [1 1 3]);
end
% Resize shortest side to 256, then center crop to 224x224
inp = imresize(inp, [256 256]);
offset = floor((256 - 224) / 2);
inp = inp(offset+1:offset+224, offset+1:offset+224, :);
% ImageNet normalization
mean_val = reshape(single([0.485, 0.456, 0.406]), [1 1 3]);
std_val  = reshape(single([0.229, 0.224, 0.225]), [1 1 3]);
inp = (inp - mean_val) ./ std_val;
% Reshape to NCHW
inp = reshape(inp, [1 size(inp)]);
inp = permute(inp, [1 4 2 3]);
inp = py.torch.tensor(inp);
```

## Python tensor to MATLAB array (dimension reordering)

PyTorch uses NCHW (batch, channels, height, width). MATLAB expects H x W x C x B (batch last, channels second-to-last). Always permute outputs back to MATLAB ordering:

```matlab
% General pattern: cast to MATLAB, then permute NCHW to H x W x C x B
result_ml = double(result.cpu().detach().numpy());  % still NCHW
result_ml = permute(result_ml, [3 4 2 1]);          % to H x W x C x B

% For single-image output (N=1), squeeze the batch dim after permuting
result_ml = squeeze(result_ml);                     % to H x W x C

% For feature vectors [N, D] to [D, N] (feature dim first, batch last)
featureVec = double(result.cpu().detach().numpy()); % [N, D]
featureVec = permute(featureVec, [2 1]);            % to [D, N]

% For masks/segmentation [N, 1, H, W] to H x W x N
mask = double(result.cpu().detach().numpy());
mask = permute(mask, [3 4 2 1]);                    % to H x W x 1 x N
mask = squeeze(mask);                               % to H x W or H x W x N
mask = imresize(mask, size(im, [1 2]));

% For labeled output
labels = uint16(outputs{1});

% For depth maps [N, 1, H, W] to H x W
depth = double(result.cpu().detach().numpy());
depth = permute(depth, [3 4 2 1]);
depth = squeeze(depth);

% For bounding boxes -- Python typically returns [x1, y1, x2, y2] (corners)
% MATLAB expects M x 4 as [startX, startY, width, height] (xywh)
boxes = double(result.cpu().detach().numpy());       % [M, 4] as [x1, y1, x2, y2]
boxes = [boxes(:,1), boxes(:,2), ...
         boxes(:,3)-boxes(:,1), boxes(:,4)-boxes(:,2)]; % to [startX, startY, w, h]

% For point clouds
wp = double(predictions{'world_points'}.cpu().detach().numpy());
```

## Display patterns

```matlab
% Overlay segmentation
imageshow(im, OverlayData=labels)

% Side-by-side comparison
imshowpair(im, mask, "montage");

% Depth visualization
imageshow(rescale(depth))

% Label overlay
imageshow(labeloverlay(im, mask))

% Point cloud
pcshow(xyz);
```

----

Copyright 2026 The MathWorks, Inc.

----
