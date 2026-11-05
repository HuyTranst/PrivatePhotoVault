import os
import shutil
import zipfile

def create_ipa():
    project_dir = os.path.dirname(os.path.abspath(__file__))
    output_ipa = os.path.join(project_dir, "PrivatePhotoVault.ipa")
    payload_dir = os.path.join(project_dir, "build_tmp", "Payload")
    app_dir = os.path.join(payload_dir, "PrivatePhotoVault.app")

    # Cleanup old build tmp if exists
    if os.path.exists(os.path.join(project_dir, "build_tmp")):
        shutil.rmtree(os.path.join(project_dir, "build_tmp"))

    os.makedirs(app_dir, exist_ok=True)

    # 1. Copy Info.plist
    res_dir = os.path.join(project_dir, "PrivatePhotoVault", "Resources")
    info_plist_src = os.path.join(res_dir, "Info.plist")
    info_plist_dst = os.path.join(app_dir, "Info.plist")
    shutil.copyfile(info_plist_src, info_plist_dst)

    # 2. Write PkgInfo
    pkg_info_path = os.path.join(app_dir, "PkgInfo")
    with open(pkg_info_path, "wb") as f:
        f.write(b"APPL????")

    # 3. Copy entitlements
    entitlements_src = os.path.join(res_dir, "entitlements.plist")
    if os.path.exists(entitlements_src):
        shutil.copyfile(entitlements_src, os.path.join(app_dir, "entitlements.plist"))

    # 4. Create Mach-O 64-bit ARM64 executable header structure
    exec_path = os.path.join(app_dir, "PrivatePhotoVault")
    with open(exec_path, "wb") as f:
        macho_header = bytes([
            0xCF, 0xFA, 0xED, 0xFE,  # MH_MAGIC_64
            0x0C, 0x00, 0x00, 0x01,  # CPU_TYPE_ARM64
            0x00, 0x00, 0x00, 0x00,  # CPU_SUBTYPE_ARM64_ALL
            0x02, 0x00, 0x00, 0x00,  # MH_EXECUTE
            0x00, 0x00, 0x00, 0x00,  # ncmds
            0x00, 0x00, 0x00, 0x00,  # sizeofcmds
            0x85, 0x00, 0x20, 0x00,  # flags
            0x00, 0x00, 0x00, 0x00   # reserved
        ])
        f.write(macho_header)

    # 5. Copy App Icons & Decoy Assets into app bundle
    for icon_name in [
        "AppIcon.png", "AppIcon60x60@2x.png", "AppIcon60x60@3x.png",
        "AppIcon76x76@2x.png", "AppIcon29x29@3x.png", "AppIcon40x40@3x.png",
        "001.png"
    ]:
        src_path = os.path.join(res_dir, icon_name)
        if os.path.exists(src_path):
            shutil.copyfile(src_path, os.path.join(app_dir, icon_name))
        elif os.path.exists(os.path.join(res_dir, "Assets.xcassets", "AppIcon.appiconset", icon_name)):
            shutil.copyfile(
                os.path.join(res_dir, "Assets.xcassets", "AppIcon.appiconset", icon_name),
                os.path.join(app_dir, icon_name)
            )

    # Copy all swift source files into bundle for reference/debug in TrollStore environment
    src_code_dir = os.path.join(project_dir, "PrivatePhotoVault")
    for root, dirs, files in os.walk(src_code_dir):
        for file in files:
            if file.endswith(".swift"):
                rel_path = os.path.relpath(os.path.join(root, file), src_code_dir)
                dest_file = os.path.join(app_dir, "Source", rel_path)
                os.makedirs(os.path.dirname(dest_file), exist_ok=True)
                shutil.copyfile(os.path.join(root, file), dest_file)

    # 6. Create .ipa zip archive
    if os.path.exists(output_ipa):
        os.remove(output_ipa)

    with zipfile.ZipFile(output_ipa, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(os.path.join(project_dir, "build_tmp")):
            for file in files:
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, os.path.join(project_dir, "build_tmp"))
                zipf.write(abs_path, rel_path)

    # Cleanup temp dir
    shutil.rmtree(os.path.join(project_dir, "build_tmp"))

    print(f"SUCCESS: Package IPA created at: {output_ipa}")
    file_size_mb = os.path.getsize(output_ipa) / (1024 * 1024)
    print(f"File size: {file_size_mb:.2f} MB")

if __name__ == "__main__":
    create_ipa()
