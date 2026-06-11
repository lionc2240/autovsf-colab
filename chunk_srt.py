import re
import os
import sys

def chunk_srt(file_path, output_dir, batch_size=50):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found.")
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split into blocks (STT, Timestamp, Content)
    blocks = re.split(r'\n\s*\n', content.strip())
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Clear existing batches in the directory to avoid mixing old/new runs
    for f in os.listdir(output_dir):
        if f.startswith('batch_') and f.endswith('.srt'):
            os.remove(os.path.join(output_dir, f))

    for i in range(0, len(blocks), batch_size):
        batch = blocks[i:i + batch_size]
        batch_num = i//batch_size + 1
        batch_filename = os.path.join(output_dir, f'batch_{batch_num}.srt')
        with open(batch_filename, 'w', encoding='utf-8') as f:
            f.write('\n\n'.join(batch))
    
    print(f"Chunking complete. Created {len(os.listdir(output_dir))} batches in {output_dir}")

if __name__ == '__main__':
    # Usage: python3 chunk_srt.py <input_srt> <output_dir> [batch_size]
    if len(sys.argv) < 3:
        print("Usage: python3 chunk_srt.py <input_srt> <output_dir> [batch_size]")
        sys.exit(1)
        
    input_srt = sys.argv[1]
    output_dir = sys.argv[2]
    batch_size = int(sys.argv[3]) if len(sys.argv) > 3 else 50
    chunk_srt(input_srt, output_dir, batch_size)
