#include <stdint.h>
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#define TAP 11

typedef struct {
	const char *label;
	const char *input_path;
	const char *output_path;
} ecg_dataset_t;

typedef struct {
	int8_t coefficients[TAP];
	int32_t stage_reg[TAP - 1];
	int32_t acc;
} fir_filter_t;

static void fir_init(fir_filter_t *state) {
	*state = (fir_filter_t){
		.coefficients = {
			-1, -1, 1, 13, 32, 41, 32, 13, 1, -1, -1
		},
		.stage_reg = {0},
		.acc = 0
	};
}

static int ensure_dir(const char *path) {
	if (mkdir(path, 0775) == 0) {
		return 0;
	}

	if (errno == EEXIST) {
		struct stat info;
		if (stat(path, &info) == 0 && S_ISDIR(info.st_mode)) {
			return 0;
		}
	}

	perror("Error creating directory");
	return 1;
}

static int ensure_output_dirs(void) {
	if (ensure_dir("../generated") != 0) {
		return 1;
	}
	if (ensure_dir("../generated/c") != 0) {
		return 1;
	}
	return 0;
}

// Basically, the Direct Form FIR filter is more straightforward and easier
// to understand, but it can be less efficient in terms of memory usage and
// computational complexity, especially for higher-order filters.
// The Transposed Form FIR filter, on the other hand, can be more efficient
// because it allows for better use of registers and can reduce the number
// of memory accesses required during filtering.
static int16_t fir_filter(fir_filter_t *state, int8_t input_sample) {
	int8_t x_in = input_sample;
	int32_t mul_v;
	int32_t new_acc;

	mul_v = (int32_t)x_in * (int32_t)state->coefficients[0];
	new_acc = mul_v + state->stage_reg[0];
	state->acc = new_acc;

	for (int i = 0; i < TAP - 2; ++i) {
		mul_v = (int32_t)x_in * (int32_t)state->coefficients[i + 1];
		state->stage_reg[i] = mul_v + state->stage_reg[i + 1];
	}

	mul_v = (int32_t)x_in * (int32_t)state->coefficients[TAP - 1];
	state->stage_reg[TAP - 2] = mul_v;

	return (int16_t)state->acc;
}

static int process_file(const char *input_path, const char *output_path, int *processed_samples) {
	FILE *fin = fopen(input_path, "r");
	if (!fin) {
		fprintf(stderr, "Error: cannot open input file '%s'\n", input_path);
		return 1;
	}

	FILE *fout = fopen(output_path, "w");
	if (!fout) {
		fprintf(stderr, "Error: cannot open output file '%s'\n", output_path);
		fclose(fin);
		return 1;
	}

	fir_filter_t filter_state;
	fir_init(&filter_state);

	char line[128];
	int count = 0;
	while (fgets(line, sizeof(line), fin) != NULL) {
		char *endptr = NULL;
		errno = 0;
		long value = strtol(line, &endptr, 10);

		if (endptr == line) {
			fprintf(stderr, "Error: invalid integer in '%s'\n", input_path);
			fclose(fin);
			fclose(fout);
			return 1;
		}

		while (*endptr != '\0' && isspace((unsigned char)*endptr) != 0) {
			++endptr;
		}

		if (*endptr != '\0') {
			fprintf(stderr, "Error: trailing characters in '%s'\n", input_path);
			fclose(fin);
			fclose(fout);
			return 1;
		}

		if (errno == ERANGE || value < INT8_MIN || value > INT8_MAX) {
			fprintf(stderr, "Error: value out of int8 range in '%s'\n", input_path);
			fclose(fin);
			fclose(fout);
			return 1;
		}

		int16_t filtered = fir_filter(&filter_state, (int8_t)value);
		fprintf(fout, "%d\n", filtered);
		++count;
	}

	fclose(fin);
	fclose(fout);

	*processed_samples = count;
	return 0;
}

int main(void) {
	if (ensure_output_dirs() != 0) {
		return 1;
	}

	const ecg_dataset_t datasets[] = {
		{"reference", "inputs/input_reference_ecg.txt", "../generated/c/output_reference_ecg.txt"},
		{"high_variability", "inputs/input_high_variability_ecg.txt", "../generated/c/output_high_variability_ecg.txt"},
		{"baseline_shifted", "inputs/input_baseline_shifted_ecg.txt", "../generated/c/output_baseline_shifted_ecg.txt"}
	};
	const int dataset_count = (int)(sizeof(datasets) / sizeof(datasets[0]));

	int total_samples = 0;
	for (int i = 0; i < dataset_count; ++i) {
		int file_samples = 0;
		if (process_file(datasets[i].input_path, datasets[i].output_path, &file_samples) != 0) {
			return 1;
		}

		total_samples += file_samples;
		printf("Processed [%s] %s -> %s (%d samples)\n",
		       datasets[i].label,
		       datasets[i].input_path,
		       datasets[i].output_path,
		       file_samples);
	}

	printf("\nFIR batch processing completed.\n");
	printf("Files processed: %d\n", dataset_count);
	printf("Total samples: %d\n", total_samples);
	return 0;
}
