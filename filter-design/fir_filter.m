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

%% Dataset configuration
% To add a new ECG in future, add one element here only.
base_dir = '/MATLAB Drive/ecg';
datasets = struct( ...
	'title', {'Baseline Shifted ECG', 'High Variability ECG', 'Reference ECG'}, ...
	'input_file', {'input_baseline_shifted_ecg.txt', 'input_high_variability_ecg.txt', 'input_reference_ecg.txt'}, ...
	'output_file', {'output_baseline_shifted_ecg.txt', 'output_high_variability_ecg.txt', 'output_reference_ecg.txt'} ...
);

num_datasets = numel(datasets);
ecg_signals = cell(1, num_datasets);
time_vectors = cell(1, num_datasets);

%% Load ECG signals and build time vectors
for k = 1:num_datasets
	input_path = fullfile(base_dir, 'inputs', datasets(k).input_file);
	ecg_signals{k} = load(input_path);
	time_vectors{k} = (0:length(ecg_signals{k}) - 1) / fs;
end

%% Plot ECG inputs separately
figure('Name', 'ECG Inputs - Separate', 'Position', [100 100 1200 800]);

for k = 1:num_datasets
	subplot(num_datasets, 1, k);
	plot(time_vectors{k}, ecg_signals{k}, 'LineWidth', 1);
	title(datasets(k).title);
	xlabel('Time [s]');
	ylabel('Amplitude');
	grid on;
end

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
filtered_signals = cell(1, num_datasets);
for k = 1:num_datasets
	filtered_signals{k} = filter(b_q, 1, ecg_signals{k});
end

%% Plot filtered ECG signals separately
figure('Name', 'Filtered ECG', 'Position', [200 200 1200 800]);

for k = 1:num_datasets
	subplot(num_datasets, 1, k);
	plot(time_vectors{k}, filtered_signals{k});
	title(['Filtered ' datasets(k).title ' quantized to 8-bit']);
	xlabel('Time [s]');
	ylabel('Amplitude');
	grid on;
end

%% Save filtered ECG signals to text files
outputs_dir = fullfile(base_dir, 'outputs');
if ~exist(outputs_dir, 'dir')
	mkdir(outputs_dir);
end

for k = 1:num_datasets
	output_path = fullfile(outputs_dir, datasets(k).output_file);
	writematrix(filtered_signals{k}, output_path);
end
