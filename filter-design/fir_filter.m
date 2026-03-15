% FIR filter design and application to ECG signals

%% Clear workspace, command window, and close all figures
clear;
clc;
close all;

%% Parameters for FIR filter design
% The standard sample rate (or sampling frequency) for ECG signals
% is often around 250 Hz, which is sufficient to capture the relevant
% frequency components of the ECG signal while keeping the data size manageable.
% The cutoff frequency of 40 Hz is chosen to remove high-frequency noise
% while preserving the important features of the ECG signal, such as
% the QRS complex and T wave, which typically lie below 40 Hz.
fs = 250; % Sample rate or sampling frequency (Hz)
fc = 40;  % Cutoff frequency (Hz)

% For this design, I choose an order of 10 for the FIR filter, which provides
% a good balance between filter performance and computational complexity.
n = 10; % Order of the filter

% The normalized frequency is calculated because
% the fir1 function expects the cutoff frequency to be in the range [0, 1],
% where 1 corresponds to the Nyquist frequency (fs / 2).
% In this case, Wn = 40 / (250 / 2) = 40 / 125 = 0.32, which means
% the cutoff frequency is at 32% of the Nyquist frequency.
% The Nyquist frequency is the highest frequency that can be accurately
% represented at a given sampling rate, and it is calculated as following:
% Nyquist frequency = fs / 2 = 250 / 2 = 125 Hz
Wn = fc / (fs / 2); % Normalized frequency

%% Load ECG signals from text files.
% Each file contains a different ECG signal with specific characteristics:
% - input_baseline_shifted_ecg.txt: This signal has a baseline shift, which is a common artifact in ECG recordings.
%                                   The baseline shift can be caused by various factors such as patient movement,
%                                   electrode issues, or changes in skin impedance. It appears as a slow drift in
%                                   the ECG signal, making it difficult to analyze the true cardiac activity.
%                                   The FIR filter will help in removing the baseline shift and restoring the true
%                                   ECG signal for accurate analysis.
% - input_high_variability_ecg.txt: This signal exhibits high variability, which can be due to arrhythmias, noise,
%                                   or other physiological factors. High variability in ECG signals can make it
%                                   challenging to identify and analyze specific features such as the P wave,
%                                   QRS complex, and T wave. The FIR filter will help in reducing the noise and
%                                   artifacts while preserving the important features of the ECG signal.
% - input_reference_ecg.txt: This is a standard ECG signal that contains only noise.
%                            The FIR filter is used to remove this noise,
%                            so the denoising effect can be evaluated clearly.
ecg1 = load('/MATLAB Drive/ecg/inputs/input_baseline_shifted_ecg.txt');
ecg2 = load('/MATLAB Drive/ecg/inputs/input_high_variability_ecg.txt');
ecg3 = load('/MATLAB Drive/ecg/inputs/input_reference_ecg.txt');

%% Time vectors for plotting
% The time vectors are created based on the length of each ECG signal and the sampling frequency.
% The time vector is calculated as follows:
% t = (0:N - 1) / fs
% where N is the number of samples in the ECG signal, and fs is the sampling frequency.
% This creates a time vector that starts at 0 seconds and increments by 1/fs seconds
% for each sample, allowing us to plot the ECG signals against time in seconds.
t1 = (0:length(ecg1) - 1) / fs;
t2 = (0:length(ecg2) - 1) / fs;
t3 = (0:length(ecg3) - 1) / fs;

%% Plot ECG inputs separately

figure('Name', 'ECG Inputs - Separate', 'Position', [100 100 1200 800]);

subplot(3, 1, 1);
plot(t1, ecg1, 'LineWidth', 1);
title('Baseline Shifted ECG');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

subplot(3, 1, 2);
plot(t2, ecg2, 'LineWidth', 1);
title('High Variability ECG');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

subplot(3, 1, 3);
plot(t3, ecg3, 'LineWidth', 1);
title('Reference ECG');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

%% FIR filter design using Hamming window
% The fir1 function is used to design the FIR filter. It takes the order of the
% filter (n), the normalized cutoff frequency (Wn), the filter type ('low' for low-pass),
% and the window type (hamming in this case) as inputs. The output is a vector of
% filter coefficients (b) that define the FIR filter.
% The Hamming window use n + 1 coefficients because the order of the filter is defined
% as the number of taps minus one, so for an order of 10, I need 11 coefficients to define the filter.
b = fir1(n, Wn, 'low', hamming(n + 1));
disp('Impulses response coefficients (floating point):');
disp(b');

%% Frequency response of the designed FIR filter
figure;
freqz(b, 1, 1024, fs);
title('Frequency Response of the Designed FIR Filter');

%% Quantization of coefficients to 8-bit signed integers
% I choose 8 bits for quantization because trying different values (upper and lower than 8)
% showed that 8 bits provide a good balance between precision and output quality.
q_bits = 8;

% During analysis of input files related to ECG signals, I observed that
% the values are positive and negative. That means I need to use signed
% integers for quantization. In fact, with 8 bits, I can represent values
% from -128 to 127 in signed integer format.
scale = 2^(q_bits - 1) - 1; % 127

% The quantized coefficients are then saturated to ensure they fit
% within the range of -128 to 127, which is the range of 8-bit signed integers.
% This means that if a coefficient exceeds 127, it will be set to 127,
% and if it is less than -128, it will be set to -128.
% This step is crucial to prevent overflow when the coefficients are used
% in fixed-point arithmetic on the FPGA.
b_q = round(b * scale);         % Quantization
b_q = max(min(b_q, 127), -128); % Saturation

disp('Quantized coefficients (8-bit signed integers):');
fprintf('%d ', b_q(1));
fprintf(', %d', b_q(2:end));
fprintf('\n');

%% Frequency response of the quantized FIR filter
figure;
freqz(b_q, 1, 1024, fs);
title('Frequency Response of the Quantized FIR Filter');

%% Application of the filter
ecg1_f = filter(b_q, 1, ecg1);
ecg2_f = filter(b_q, 1, ecg2);
ecg3_f = filter(b_q, 1, ecg3);

%% Plot filtered ECG signals separately

figure('Name','Filtered ECG','Position',[200 200 1200 800]);

subplot(3,1,1);
plot(t1, ecg1_f);
title('Filtered Baseline Shifted ECG quantized to 8-bit');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

subplot(3,1,2);
plot(t2, ecg2_f);
title('Filtered High Variability ECG quantized to 8-bit');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

subplot(3,1,3);
plot(t3, ecg3_f);
title('Filtered Reference ECG quantized to 8-bit');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

%% Save filtered ECG signals to text files
writematrix(ecg1_f, '/MATLAB Drive/ecg/output_baseline_shifted_ecg.txt');
writematrix(ecg2_f, '/MATLAB Drive/ecg/output_high_variability_ecg.txt');
writematrix(ecg3_f, '/MATLAB Drive/ecg/output_reference_ecg.txt');
