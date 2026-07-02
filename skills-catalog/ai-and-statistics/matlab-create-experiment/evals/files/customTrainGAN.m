% customTrainGAN.m — Custom training loop for a simple GAN
% Located at: /projects/gan/customTrainGAN.m

numLatent = 100;
numEpochs = 50;
learnRate = 0.0002;
miniBatchSize = 128;

% Generator network
netG = dlnetwork([
    featureInputLayer(numLatent)
    fullyConnectedLayer(256)
    reluLayer
    fullyConnectedLayer(784)
    sigmoidLayer]);

% Discriminator network
netD = dlnetwork([
    featureInputLayer(784)
    fullyConnectedLayer(256)
    learnableLeakyReluLayer(0.2)
    fullyConnectedLayer(1)
    sigmoidLayer]);

for epoch = 1:numEpochs
    % Generate fake data
    Z = dlarray(randn(numLatent, miniBatchSize), 'CB');
    fake = predict(netG, Z);

    % Discriminator loss
    [gradD, lossD] = dlfeval(@discriminatorLoss, netD, fake, realData);
    netD = adamupdate(netD, gradD, [], [], epoch, learnRate);

    % Generator loss
    [gradG, lossG] = dlfeval(@generatorLoss, netG, netD, Z);
    netG = adamupdate(netG, gradG, [], [], epoch, learnRate);

    fprintf('Epoch %d: D loss = %.4f, G loss = %.4f\n', epoch, lossD, lossG);
end

% Copyright 2026 The MathWorks, Inc.
