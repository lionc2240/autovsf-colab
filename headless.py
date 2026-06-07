import sys, os, time, datetime, argparse, re
from pathlib import Path
import subprocess
import config as C
import ocr

def log(msg):
    print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}")

def get_video_duration(video_path):
    try:
        cmd = [
            "ffprobe", "-v", "error", "-show_entries", "format=duration", 
            "-of", "default=noprint_wrappers=1:nokey=1", video_path
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        return float(result.stdout.strip())
    except:
        return 0.0

def run_headless(video_path, top=0.3, bottom=0.0, left=0.0, right=1.0, output_dir=None, skip_if_exists=False):
    video = os.path.abspath(video_path)
    if not os.path.isfile(video):
        print(f"❌ Video file not found: {video}")
        return

    # 1. Determine output paths
    if output_dir is None:
        if os.path.exists("/content"):
            output_dir = os.path.join("/content", Path(video).stem + "_out")
        else:
            output_dir = str(Path(video).parent / (Path(video).stem + "_out"))
    
    rgb_dir = os.path.join(output_dir, "RGBImages")
    
    # Check for existing images if skip_if_exists is True
    should_run_vsf = True
    if skip_if_exists and os.path.exists(rgb_dir):
        img_count = len([f for f in os.listdir(rgb_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))])
        if img_count > 0:
            log(f"♻️ Found {img_count} existing images in {rgb_dir}. Skipping VideoSubFinder scan.")
            should_run_vsf = False

    # Final SRT always stays near the video on Drive by default
    srt_out = str(Path(video).with_suffix('.srt'))

    # Reset state for new run
    C.state.reset()
    C.state.video_duration = get_video_duration(video)
    C.state.t0 = time.time()

    # 1. Run VideoSubFinder
    cfg = C.load()
    vsf = cfg["vsf_path"]
    
    if not os.path.exists(vsf):
        log(f"❌ VideoSubFinder binary not found at: {vsf}")
        return

    vsf_dir = os.path.dirname(vsf)
    
    if should_run_vsf:
        log(f"🚀 Starting video scan: {Path(video).name}")
        log(f"📂 Output directory: {output_dir}")
        log(f"📝 Final SRT will be saved at: {srt_out}")
        log(f"✂️  Scan area (Crop): top={top}, bottom={bottom}, left={left}, right={right}")

        cmd = [
            vsf,
            "-c", "-r", 
            "-i", video,
            "-o", output_dir,
            "-te", f"{top:.4f}",
            "-be", f"{bottom:.4f}",
            "-le", f"{left:.4f}",
            "-re", f"{right:.4f}"
        ]

        # Ensure output dir exists
        if not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)

        log(f"💻 Running command: {' '.join(cmd)}")
        log(f"📁 Working directory: {vsf_dir}")

        # Parse progress from stdout and log to console for debugging
        progress_re = re.compile(r'(\d+)\s*%')
        log("🔄 Launching VideoSubFinder...")
        
        try:
            # Add execution permission just in case
            os.chmod(vsf, 0o755)
            
            with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=vsf_dir) as proc:
                for line in proc.stdout:
                    line = line.strip()
                    if line:
                        print(f"[VSF] {line}")
                        match = progress_re.search(line)
                        if match:
                            C.state.scan_progress = float(match.group(1))
                proc.wait()
                if proc.returncode != 0:
                    log(f"❌ VideoSubFinder exited with code {proc.returncode}")
        except Exception as e:
            log(f"❌ Failed to execute VideoSubFinder: {str(e)}")
            return
        
        log("✅ Video scan finished.")
    
    # 2. Run OCR
    if not os.path.exists(rgb_dir):
        print(f"❌ Images folder not found: {rgb_dir}")
        return

    log(f"⚡ Starting OCR in: {rgb_dir}")
    C.state.t0 = time.time() # Reset t0 for Phase 2 accuracy
    
    def on_progress(done, total):
        print(f"\r⏳ OCR Progress: {done}/{total} images", end="")

    def on_finish(path):
        print(f"\n✅ Success! Subtitle file: {path}")

    ocr.run(rgb_dir, srt_out, 
            cfg.get("delete_raw_texts", False), 
            cfg.get("delete_texts", False),
            log, on_progress, on_finish)

    # Keep script running until OCR is done
    while True:
        if C.state.total > 0 and C.state.done >= C.state.total:
            time.sleep(2) # Wait for file write
            break
        if C.state.stop_event.is_set():
            break
        time.sleep(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AutoVSF Headless - Subtitle Extraction")
    parser.add_argument("video", help="Path to video file")
    parser.add_argument("--top", type=float, default=0.3, help="Top crop (0.0-1.0)")
    parser.add_argument("--bottom", type=float, default=0.0, help="Bottom crop (0.0-1.0)")
    parser.add_argument("--left", type=float, default=0.0, help="Left crop (0.0-1.0)")
    parser.add_argument("--right", type=float, default=1.0, help="Right crop (0.0-1.0)")
    parser.add_argument("--output", help="Temporary output directory for images")
    parser.add_argument("--skip", action="store_true", help="Skip VideoSubFinder if images already exist")

    args = parser.parse_args()
    
    run_headless(args.video, args.top, args.bottom, args.left, args.right, args.output, args.skip)

