# 5G Link Noise: Noise Variance for the Receiver

5G Toolbox specific. Covers adding AWGN at a per-subcarrier SNR to a 5G
downlink waveform and deriving the noise variance the frequency-domain
receiver needs for MMSE equalization and PDSCH decoding.

## Adding noise at a per-subcarrier SNR

`nrTDLChannel` and `nrCDLChannel` default to `NormalizeChannelOutputs=true`,
which divides the channel output power by the number of receive antennas.
Match the noise scaling used in the shipped 5G examples:

    SNR = 10^(snrPerSC_dB/10);
    N0  = 1/sqrt(nRxAnts*nfft*SNR);
    rxNoisy = rxWaveform + N0*randn(size(rxWaveform), "like", rxWaveform);

If `NormalizeChannelOutputs=false`, drop the `nRxAnts` factor:
`N0 = 1/sqrt(nfft*SNR)`.

The `"like"` draws complex noise at the correct variance; without it, `randn`
returns real-only noise and halves the noise power. `nfft` is the OFDM FFT
length (`nrOFDMInfo` reports it as `Nfft`).

The same noise level can be added with `awgn` using the analytical signal
power (identical result), which also avoids computing the active subcarrier
count:

    % NormalizeChannelOutputs=true (default)
    rxNoisy = awgn(rxWaveform, snrPerSC_dB, -10*log10(double(nfft*nRxAnts)));

    % NormalizeChannelOutputs=false
    rxNoisy = awgn(rxWaveform, snrPerSC_dB, -10*log10(double(nfft)));

These forms assume unit-power subcarrier symbols (e.g.,
`qammod(..., UnitAveragePower=true)`). If the modulator uses default
constellation scaling, the analytical signal power is
`numAvailableSC * meanSymbolPower / nfft^2` with
`meanSymbolPower = mean(abs(symbols).^2)`.

## Noise variance for the equalizer and demodulator

The equalizer and the PDSCH decoder operate on the frequency-domain grid,
after `nrOFDMDemodulate`. The FFT scales the time-domain noise variance
(`N0^2`) by `nfft`, so the frequency-domain noise variance is:

    nVar = N0^2 * nfft;

Pass `nVar` as the last argument to both the equalizer and the demodulator:

    nrEqualizeMMSE(___,nVar)
    nrPDSCHDecode(___,nVar)

This is the frequency-domain counterpart of the generic soft-demod rule in
SKILL.md ("scale the time-domain noise variance by `nfft`"). Keep the same
`N0` throughout so the noise added to the waveform and the `nVar` fed to the
receiver stay consistent.

Copyright 2026 The MathWorks, Inc.
