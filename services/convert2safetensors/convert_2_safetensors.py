import argparse
import json
import os
import shutil
import torch
from collections import defaultdict
from safetensors.torch import load_file, save_file
from tqdm import tqdm


def shared_pointers(tensors):
    ptrs = defaultdict(list)
    for k, v in tensors.items():
        ptrs[v.data_ptr()].append(k)
    return [names for names in ptrs.values() if len(names) > 1]


def check_file_size(sf_filename, pt_filename):
    sf_size = os.stat(sf_filename).st_size
    pt_size = os.stat(pt_filename).st_size
    if (sf_size - pt_size) / pt_size > 0.01:
        raise RuntimeError(f"File size difference exceeds 1% between {sf_filename} and {pt_filename}")


def convert_file(pt_filename, sf_filename, copy_add_data=True, allow_pickle=False):
    try:
        loaded = torch.load(pt_filename, map_location="cpu", weights_only=not allow_pickle)
    except Exception as e:
        print(f"[WARNING] Failed to load '{pt_filename}': {e}")
        return  # Skip this file
    loaded = loaded.get("state_dict", loaded)
    shared = shared_pointers(loaded)

    for shared_weights in shared:
        for name in shared_weights[1:]:
            loaded.pop(name)

    loaded = {k: v.contiguous().half() for k, v in loaded.items()}

    source_folder = os.path.dirname(pt_filename)
    dest_folder = os.path.dirname(sf_filename)
    os.makedirs(dest_folder, exist_ok=True)
    save_file(loaded, sf_filename, metadata={"format": "pt"})
    check_file_size(sf_filename, pt_filename)
    if copy_add_data:
        copy_additional_files(source_folder, dest_folder)

    reloaded = load_file(sf_filename)
    for k, v in loaded.items():
        if not torch.equal(v, reloaded[k]):
            raise RuntimeError(f"Mismatch in tensors for key {k}.")


def rename(pt_filename):
    filename, ext = os.path.splitext(pt_filename)
    local = f"{filename}.safetensors"
    local = local.replace("pytorch_model", "model")
    return local


def copy_additional_files(source_folder, dest_folder):
    for file in os.listdir(source_folder):
        file_path = os.path.join(source_folder, file)
        if os.path.isfile(file_path) and not file.endswith(('.bin', '.py', '.pt', '.pth')):
            shutil.copy(file_path, dest_folder)


def find_index_file(source_folder):
    for file in os.listdir(source_folder):
        if file.endswith('.bin.index.json'):
            return file
    return None


def convert_files(source_folder, dest_folder, delete_old, use_dest_folder, allow_pickle):
    index_file = find_index_file(source_folder)
    if index_file:
        index_file = os.path.join(source_folder, index_file)
        with open(index_file) as f:
            index_data = json.load(f)
        for pt_filename in tqdm(set(index_data["weight_map"].values()), desc="Converting files"):
            full_pt_filename = os.path.join(source_folder, pt_filename)
            sf_filename = os.path.join(dest_folder, rename(pt_filename)) if use_dest_folder else os.path.join(
                os.path.dirname(full_pt_filename), rename(pt_filename))
            convert_file(full_pt_filename, sf_filename, copy_add_data=False, allow_pickle=allow_pickle)
            if delete_old:
                os.remove(full_pt_filename)
        index_path = os.path.join(dest_folder, "model.safetensors.index.json") if use_dest_folder else os.path.join(
            os.path.dirname(index_file), "model.safetensors.index.json")
        with open(index_path, "w") as f:
            new_map = {k: rename(v) for k, v in index_data["weight_map"].items()}
            json.dump({**index_data, "weight_map": new_map}, f, indent=4)
    else:
        for pt_filename in tqdm(os.listdir(source_folder), desc="Converting files"):
            if pt_filename.endswith(('.bin', '.pt', '.pth')):
                full_pt_filename = os.path.join(source_folder, pt_filename)
                sf_filename = os.path.join(dest_folder, rename(pt_filename)) if use_dest_folder else os.path.join(
                    os.path.dirname(full_pt_filename), rename(pt_filename))
                convert_file(full_pt_filename, sf_filename, copy_add_data=False, allow_pickle=allow_pickle)
                if delete_old:
                    os.remove(full_pt_filename)

    copy_additional_files(source_folder, dest_folder)


def convert_batch(source_dir, dest_dir, delete_old, use_dest_folder, allow_pickle):
    files_to_convert = []
    for root, _, files in os.walk(source_dir):
        for file in files:
            if file.endswith(('.bin', '.pt', '.pth')):
                files_to_convert.append(os.path.join(root, file))
    for full_model_path in tqdm(files_to_convert, desc="Converting batch of models"):
        sf_filename = os.path.join(dest_dir, os.path.relpath(rename(full_model_path),
                                                             source_dir)) if use_dest_folder else os.path.join(
            os.path.dirname(full_model_path), rename(full_model_path))
        os.makedirs(os.path.dirname(sf_filename), exist_ok=True)
        convert_file(full_model_path, sf_filename, copy_add_data=False, allow_pickle=allow_pickle)
        if delete_old:
            os.remove(full_model_path)


def main():
    parser = argparse.ArgumentParser(description="Convert PyTorch model files to SafeTensors format.")
    parser.add_argument("--source", required=False, default=os.getcwd(),
                        help="Source folder containing .pth/.pt/.bin files")
    parser.add_argument("--dest", required=False,
                        help="Destination folder for .safetensors files. If not specified, will use default.")
    parser.add_argument("--delete-old", action="store_true",
                        help="Delete original PyTorch files after conversion")
    parser.add_argument("--batch", action="store_true",
                        help="Recursively convert a batch of models from subdirectories")
    parser.add_argument("--allow-pickle", action="store_true",
                        help="Allow loading legacy models with full object deserialization (trusted sources only!)")

    args = parser.parse_args()

    source_folder = os.path.abspath(args.source)
    dest_folder = os.path.abspath(args.dest) if args.dest else os.path.join(
        source_folder, os.path.basename(source_folder) + "_safetensors")
    use_dest_folder = bool(args.dest)

    if args.batch:
        convert_batch(source_folder, dest_folder, args.delete_old, use_dest_folder, args.allow_pickle)
    else:
        if any(fname.endswith(('.bin', '.pt', '.pth')) for fname in os.listdir(source_folder)):
            if "pytorch_model.bin" in os.listdir(source_folder):
                sf_filename = os.path.join(dest_folder, "model.safetensors") if use_dest_folder else os.path.join(
                    source_folder, "model.safetensors")
                convert_file(os.path.join(source_folder, "pytorch_model.bin"), sf_filename,
                             copy_add_data=True, allow_pickle=args.allow_pickle)
                if args.delete_old:
                    os.remove(os.path.join(source_folder, "pytorch_model.bin"))
            else:
                convert_files(source_folder, dest_folder, args.delete_old, use_dest_folder, args.allow_pickle)
        else:
            raise RuntimeError("No valid model files found in the specified directory.")


if __name__ == "__main__":
    main()
