import os
import sys
import re

def merge_srt_batches(output_file, input_dir):
    if not os.path.exists(input_dir):
        print(f"Error: Input directory {input_dir} not found.")
        sys.exit(1)

    # Get all translated batch files and sort them numerically
    batch_files = [f for f in os.listdir(input_dir) if f.startswith('batch_') and f.endswith('_translated.srt')]
    
    def get_num(filename):
        match = re.search(r'batch_(\d+)', filename)
        return int(match.group(1)) if match else 0
        
    batch_files.sort(key=get_num)

    if not batch_files:
        print("Error: No translated batch files found to merge.")
        sys.exit(1)

    with open(output_file, 'w', encoding='utf-8') as outfile:
        for i, filename in enumerate(batch_files):
            file_path = os.path.join(input_dir, filename)
            with open(file_path, 'r', encoding='utf-8') as infile:
                content = infile.read().strip()
                outfile.write(content)
                if i < len(batch_files) - 1:
                    outfile.write('\n\n')
    
    print(f"Merging complete. Final file saved at: {output_file}")

if __name__ == '__main__':
    # Usage: python3 merge_batches.py <output_srt> <input_dir>
    if len(sys.argv) < 3:
        print("Usage: python3 merge_batches.py <output_srt> <input_dir>")
        sys.exit(1)
        
    output_srt = sys.argv[1]
    input_dir = sys.argv[2]
    merge_srt_batches(output_srt, input_dir)
