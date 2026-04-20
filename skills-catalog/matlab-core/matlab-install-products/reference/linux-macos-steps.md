# Linux/macOS Steps for mpm Installation

## Step 1 - Download mpm

Create the working folder with `mkdir -p /tmp/mpm-YYYYMMDD-HHMMSS`, then print a progress message (`echo "Downloading mpm - this may take a few minutes..."`), use `curl -fL -o` to download mpm to `<user home>/Downloads/mpm`, and `chmod +x` to make it executable.

```sh
set -eu
working_folder="/tmp/mpm-YYYYMMDD-HHMMSS"
mkdir -p "$working_folder"
mpm_path="$HOME/Downloads/mpm"

if [ -f "$mpm_path" ]; then
  echo "mpm already present at $mpm_path"
else
  echo "Downloading mpm - this may take a few minutes..."
  curl -fL -o "$mpm_path" "https://www.mathworks.com/mpm/glnxa64/mpm"  # Linux
  # macOS: curl -fL -o "$mpm_path" "https://www.mathworks.com/mpm/maca64/mpm"
  chmod +x "$mpm_path"
  echo "mpm downloaded to $mpm_path"
fi
```

## Step 2 - Download and edit the release input file

```sh
set -eu
release="R2025b"
working_folder="/tmp/mpm-YYYYMMDD-HHMMSS"
input_url="https://raw.githubusercontent.com/mathworks-ref-arch/matlab-dockerfile/refs/heads/main/mpm-input-files/${release}/mpm_input_${release,,}.txt"
input_file="${working_folder}/mpm_input_${release,,}.txt"

curl -fL -o "$input_file" "$input_url"

if [ ! -f "$input_file" ]; then
  echo "Input file was not downloaded: $input_file" >&2
  exit 1
fi

expected_destination="/usr/local/MATLAB/R2025b"
requested_products="product.MATLAB product.Simulink"

# Edit: set destinationFolder and add noJRE=true
sed -i'' "s|^#*\s*destinationFolder=.*|destinationFolder=$expected_destination|" "$input_file"
sed -i'' "/^destinationFolder=/a noJRE=true" "$input_file"

# Edit: uncomment requested products
for product in $requested_products; do
  sed -i'' "s|^#\s*\(${product}\)\s*$|\1|" "$input_file"
done

# Verify: destinationFolder
destination_line=$(grep -E '^destinationFolder=' "$input_file" | tr -d '\r')
if [ "$destination_line" != "destinationFolder=$expected_destination" ]; then
  echo "destinationFolder mismatch: $destination_line" >&2
  exit 1
fi

# Verify: no unrequested products uncommented
uncommented_products=$(grep -E '^[[:space:]]*product\.' "$input_file" | tr -d '\r')
for line in $uncommented_products; do
  case " $requested_products " in
    *" $line "*) ;;
    *) echo "Unrequested product enabled: $line" >&2; exit 1 ;;
  esac
done

# Verify: all requested products are uncommented
for product in $requested_products; do
  grep -qx "$product" "$input_file" || { echo "Requested product not enabled: $product" >&2; exit 1; }
done
```

## Step 3 - Run the install command

```sh
set -eu
MPM="$HOME/Downloads/mpm"
input_file="/tmp/mpm-YYYYMMDD-HHMMSS/mpm_input_r2025b.txt"

echo "Running: $MPM install --inputfile=\"$input_file\""
"$MPM" install --inputfile="$input_file"
```

Completion artifact: `<DESTINATION>/bin/matlab` (Linux) or `<DESTINATION>/Contents/MacOS/MATLAB` (macOS).

----

Copyright 2026 The MathWorks, Inc.

----

