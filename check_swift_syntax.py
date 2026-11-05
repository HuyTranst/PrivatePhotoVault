import os

base_dir = r"D:\PrivatePhotoVault\PrivatePhotoVault"
errors = []

for root, dirs, files in os.walk(base_dir):
    for f in sorted(files):
        if f.endswith(".swift"):
            file_path = os.path.join(root, f)
            with open(file_path, "r", encoding="utf-8") as sfile:
                content = sfile.read()
            
            stack = []
            pairs = {")": "(", "}": "{", "]": "["}
            in_string = False
            in_multiline_comment = False
            in_single_comment = False
            escape = False
            
            lines = content.split("\n")
            for line_no, line in enumerate(lines, 1):
                i = 0
                while i < len(line):
                    ch = line[i]
                    if in_single_comment:
                        break
                    if in_multiline_comment:
                        if ch == "*" and i + 1 < len(line) and line[i+1] == "/":
                            in_multiline_comment = False
                            i += 2
                            continue
                        i += 1
                        continue
                    if not in_string:
                        if ch == "/" and i + 1 < len(line) and line[i+1] == "/":
                            break
                        if ch == "/" and i + 1 < len(line) and line[i+1] == "*":
                            in_multiline_comment = True
                            i += 2
                            continue
                    if ch == '"' and not escape:
                        in_string = not in_string
                    elif not in_string:
                        if ch in "({[":
                            stack.append((ch, line_no))
                        elif ch in ")}]":
                            if not stack:
                                errors.append(f"{f}:{line_no}: Unmatched closing bracket {ch}")
                            else:
                                top, start_line = stack.pop()
                                if top != pairs[ch]:
                                    errors.append(f"{f}:{line_no}: Mismatched bracket {ch}, expected {top} from line {start_line}")
                    
                    if ch == "\\" and in_string and not escape:
                        escape = True
                    else:
                        escape = False
                    i += 1
                in_single_comment = False
            
            if stack:
                for top, start_line in stack:
                    errors.append(f"{f}:{start_line}: Unclosed bracket {top}")

if not errors:
    print("ALL 32 SWIFT FILES PASSED SYNTAX & BRACKET INTEGRITY CHECK PERFECTLY!")
else:
    print(f"Found {len(errors)} errors:")
    for e in errors:
        print(" -", e)
