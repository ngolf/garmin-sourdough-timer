"""Build unchanged app sources for eligible installed Connect IQ devices."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--devices", type=Path, required=True)
    parser.add_argument("--key", type=Path, required=True)
    parser.add_argument("--device", help="Check a single installed device (does not update manifest)")
    parser.add_argument("--update-manifest", action="store_true")
    args = parser.parse_args()
    if args.device and args.update_manifest:
        parser.error("--device cannot be combined with --update-manifest")
    root = Path(__file__).resolve().parents[1]
    compiler = args.sdk / "bin" / ("monkeyc.bat" if os.name == "nt" else "monkeyc")
    for path in (compiler, args.devices, args.key):
        if not path.exists():
            parser.error(f"Required path does not exist: {path}")
    manifest_path = root / "manifest.xml"
    manifest = manifest_path.read_text(encoding="utf-8")
    namespace = {"iq": "http://www.garmin.com/xml/connectiq"}
    application = ET.fromstring(manifest).find("iq:application", namespace)
    minimum = tuple(map(int, application.attrib["minApiLevel"].split(".")))
    if args.device and not (args.devices / args.device / "compiler.json").exists():
        parser.error(f"Device is not installed: {args.device}")
    output = root / "bin" / "compatibility"
    output.mkdir(parents=True, exist_ok=True)
    candidates = []
    results = []
    for directory in sorted(args.devices.iterdir()):
        if not directory.is_dir():
            continue
        if args.device and directory.name != args.device:
            continue
        compiler_json = directory / "compiler.json"
        simulator_json = directory / "simulator.json"
        if not compiler_json.exists() or not simulator_json.exists():
            results.append({"device": directory.name, "status": "excluded",
                            "detail": "Missing device metadata", "family": ""})
            continue
        device = json.loads(compiler_json.read_text(encoding="utf-8"))
        simulator = json.loads(simulator_json.read_text(encoding="utf-8"))
        keys = {key["id"] for key in simulator.get("keys", [])}
        versions = [tuple(map(int, part["connectIQVersion"].split(".")))
                    for part in device.get("partNumbers", [])]
        reason = ""
        if not any(app["type"] == "watchApp" for app in device.get("appTypes", [])):
            reason = "No watch-app support"
        elif not device.get("deviceFamily", "").startswith("round-"):
            reason = "Non-round layout not validated"
        elif not {"enter", "up", "down", "menu", "esc"} <= keys:
            reason = "Missing required button mappings"
        elif not versions or max(versions) < minimum:
            reason = "API below manifest minimum"
        row = {"device": directory.name, "family": device.get("deviceFamily", ""),
               "status": "excluded" if reason else "candidate", "detail": reason}
        if reason:
            results.append(row)
        else:
            candidates.append(row)

    def build(row):
        device_id = row["device"]
        log = output / f"{device_id}.log"
        with tempfile.TemporaryDirectory(prefix="ciq-compat-") as temp:
            temp = Path(temp)
            products = ('<iq:products><iq:product id="' + device_id +
                        '"/></iq:products>')
            single_manifest = re.sub(r"<iq:products>.*?</iq:products>", products,
                                     manifest, flags=re.DOTALL)
            (temp / "manifest.xml").write_text(single_manifest, encoding="utf-8")
            jungle = temp / "monkey.jungle"
            jungle.write_text(
                f'project.manifest = "{temp / "manifest.xml"}"\n'
                f'base.sourcePath = "{root / "source"}";"{root / "tests"}"\n'
                f'base.resourcePath = "{root / "resources"}"\n', encoding="utf-8")
            command = [str(compiler), "-f", str(jungle), "-d", device_id,
                       "-y", str(args.key.resolve()), "-o",
                       str(output / f"{device_id}.prg"), "-l", "3", "-w"]
            try:
                process = subprocess.run(command, cwd=root, stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT, text=True,
                                         encoding="utf-8", errors="replace", timeout=180)
                log.write_text(process.stdout, encoding="utf-8")
                row["status"] = "build-passed" if process.returncode == 0 else "build-failed"
                row["detail"] = "Not simulator-validated" if process.returncode == 0 else log.name
            except subprocess.TimeoutExpired:
                row["status"] = "build-failed"
                row["detail"] = "Compiler timed out after 180 seconds"
                log.write_text(row["detail"], encoding="utf-8")
        print(f"{device_id}: {row['status']}", flush=True)
        return row

    with ThreadPoolExecutor(max_workers=2) as pool:
        results.extend(pool.map(build, candidates))
    results.sort(key=lambda row: row["device"])
    report = output / "results.csv"
    with report.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=["device", "family", "status", "detail"])
        writer.writeheader()
        writer.writerows(results)
    passed = [row["device"] for row in results if row["status"] == "build-passed"]
    if args.update_manifest:
        if not passed:
            raise SystemExit("No builds passed; manifest left unchanged.")
        products = "<iq:products>\n" + "".join(
            f'            <iq:product id="{device}"/>\n' for device in passed
        ) + "        </iq:products>"
        updated = re.sub(r"<iq:products>.*?</iq:products>", products,
                         manifest, flags=re.DOTALL)
        with manifest_path.open("w", encoding="utf-8", newline="") as file:
            file.write(updated.replace("\n", "\r\n"))
        print(f"Manifest updated with {len(passed)} build-passed products.")
    print(f"{len(passed)}/{len(candidates)} candidates passed. Report: {report}")
    if any(row["status"] == "build-failed" for row in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
