import os

base_dir = r"D:\PrivatePhotoVault"
swift_files = []
for root, dirs, files in os.walk(os.path.join(base_dir, "PrivatePhotoVault")):
    for f in sorted(files):
        if f.endswith(".swift"):
            rel_path = os.path.relpath(os.path.join(root, f), os.path.join(base_dir, "PrivatePhotoVault"))
            swift_files.append((f, rel_path.replace("\\", "/")))

print(f"Found {len(swift_files)} Swift files.")

build_files = []
file_refs = []
sources_entries = []
group_entries = []

for idx, (filename, rel_path) in enumerate(swift_files, 1):
    build_id = f"A1{idx:06d}2C9F000000000001"
    ref_id = f"B1{idx:06d}2C9F000000000001"
    build_files.append(f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {filename} */; }};")
    file_refs.append(f'\t\t{ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{filename}"; path = "{rel_path}"; sourceTree = "<group>"; }};')
    sources_entries.append(f"\t\t\t\t{build_id} /* {filename} in Sources */,")
    group_entries.append(f"\t\t\t\t{ref_id} /* {filename} */,")

# Add Info.plist and entitlements
file_refs.append('\t\tB19999982C9F000000000001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "Info.plist"; path = "Resources/Info.plist"; sourceTree = "<group>"; };')
file_refs.append('\t\tB19999992C9F000000000001 /* entitlements.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "entitlements.plist"; path = "Resources/entitlements.plist"; sourceTree = "<group>"; };')
group_entries.append("\t\t\t\tB19999982C9F000000000001 /* Info.plist */,")
group_entries.append("\t\t\t\tB19999992C9F000000000001 /* entitlements.plist */,")

build_files_str = "\n".join(build_files)
file_refs_str = "\n".join(file_refs)
sources_entries_str = "\n".join(sources_entries)
group_entries_str = "\n".join(group_entries)

pbxproj_content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 54;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files_str}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\tB10000002C9F000000000000 /* PrivatePhotoVault.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PrivatePhotoVault.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{file_refs_str}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\tC10000002C9F000000000000 /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\tD10000002C9F000000000000 = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tD10000012C9F000000000001 /* PrivatePhotoVault */,
\t\t\t\tD10000022C9F000000000002 /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\tD10000012C9F000000000001 /* PrivatePhotoVault */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_entries_str}
\t\t\t);
\t\t\tpath = PrivatePhotoVault;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\tD10000022C9F000000000002 /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tB10000002C9F000000000000 /* PrivatePhotoVault.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\tE10000002C9F000000000000 /* PrivatePhotoVault */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = F10000002C9F000000000000 /* Build configuration list for PBXNativeTarget "PrivatePhotoVault" */;
\t\t\tbuildPhases = (
\t\t\t\tF10000012C9F000000000001 /* Sources */,
\t\t\t\tC10000002C9F000000000000 /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = PrivatePhotoVault;
\t\t\tproductName = PrivatePhotoVault;
\t\t\tproductReference = B10000002C9F000000000000 /* PrivatePhotoVault.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t010000002C9F000000000000 /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\tE10000002C9F000000000000 = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = 010000012C9F000000000001 /* Build configuration list for PBXProject "PrivatePhotoVault" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = D10000002C9F000000000000;
\t\t\tproductRefGroup = D10000022C9F000000000002 /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\tE10000002C9F000000000000 /* PrivatePhotoVault */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\tF10000012C9F000000000001 /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_entries_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\tG10000012C9F000000000001 /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\tG10000022C9F000000000002 /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\tH10000012C9F000000000001 /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tINFOPLIST_FILE = PrivatePhotoVault/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.secure.photovault;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\tH10000022C9F000000000002 /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tINFOPLIST_FILE = PrivatePhotoVault/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.secure.photovault;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t010000012C9F000000000001 /* Build configuration list for PBXProject "PrivatePhotoVault" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tG10000012C9F000000000001 /* Debug */,
\t\t\t\tG10000022C9F000000000002 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\tF10000002C9F000000000000 /* Build configuration list for PBXNativeTarget "PrivatePhotoVault" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tH10000012C9F000000000001 /* Debug */,
\t\t\t\tH10000022C9F000000000002 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = 010000002C9F000000000000 /* Project object */;
}}
"""

pbxproj_path = os.path.join(base_dir, "PrivatePhotoVault.xcodeproj", "project.pbxproj")
with open(pbxproj_path, "w", encoding="utf-8") as f:
    f.write(pbxproj_content)

print(f"Successfully generated {pbxproj_path}")
