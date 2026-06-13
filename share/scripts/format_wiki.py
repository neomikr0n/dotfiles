import re
import sys

def process_markdown(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    out_lines = []
    in_code_block = False
    code_block_lines = []

    def flush_code_block():
        if not code_block_lines: return
        # detect lang
        lang = ''
        first_line = code_block_lines[0].strip()
        if first_line == '```':
            content = ''.join(code_block_lines[1:])
            if re.search(r'\b(sudo|yay|pacman|apt|systemctl|git|chmod|chown|ls|cd|grep|busctl|export|env)\b', content):
                lang = 'bash'
            elif re.search(r'</?\w+>', content):
                lang = 'xml'
            elif '{' in content and '}' in content:
                lang = 'json'
            code_block_lines[0] = f'```{lang}\n'
        
        out_lines.extend(code_block_lines)
        code_block_lines.clear()

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith('```'):
            if not in_code_block:
                in_code_block = True
                code_block_lines.append(line)
            else:
                code_block_lines.append(line)
                flush_code_block()
                in_code_block = False
            i += 1
            continue
            
        if in_code_block:
            code_block_lines.append(line)
            i += 1
            continue

        # Check for >>>
        if stripped.startswith('>>> '):
            # Transform into Github alert Note or standard quote
            content = line.replace('>>>', '>').strip()
            if content == '>':
                content = ''
            
            # Check previous line to see if we already started a NOTE block
            if not (out_lines and out_lines[-1].startswith('> ')):
                out_lines.append('> [!NOTE]\n')
            
            if content:
                out_lines.append(f'{content}\n')
            
            i += 1
            continue

        if stripped == '>>>' or stripped == '>>' or stripped == '>>>>':
            i += 1
            continue
            
        if stripped.startswith('>> ') and not stripped.startswith('>>> '):
            i += 1
            continue

        # Clean quoted headers > # **[Title]** -> # Title
        header_match = re.match(r'^>\s*(#+)\s*\**\[?(.*?)\]?\**$', stripped)
        if header_match:
            hashes, title = header_match.groups()
            title = title.replace('*', '').strip()
            # Ensure blank line before header
            if out_lines and out_lines[-1].strip() != '':
                out_lines.append('\n')
            out_lines.append(f'{hashes} {title}\n')
            i += 1
            continue

        # Clean * ## title -> ## title
        list_header = re.match(r'^\*\s+(#+)\s+(.*)', stripped)
        if list_header:
            hashes, title = list_header.groups()
            if out_lines and out_lines[-1].strip() != '':
                out_lines.append('\n')
            out_lines.append(f'{hashes} {title}\n')
            i += 1
            continue
            
        # Clean plain # **[Title]**
        plain_header = re.match(r'^(#+)\s*\**\[?(.*?)\]?\**$', stripped)
        if plain_header and not stripped.startswith('# '):
            hashes, title = plain_header.groups()
            title = title.replace('*', '').strip()
            if out_lines and out_lines[-1].strip() != '':
                 out_lines.append('\n')
            out_lines.append(f'{hashes} {title}\n')
            i += 1
            continue
            
        # Standardize headers
        if re.match(r'^(#+)\s', line):
            if out_lines and out_lines[-1].strip() != '':
                 out_lines.append('\n')

        out_lines.append(line)
        i += 1

    # Remove extra blank lines
    final_lines = []
    blank_count = 0
    for line in out_lines:
        if not line.strip():
            blank_count += 1
        else:
            blank_count = 0
        if blank_count <= 2:
            final_lines.append(line)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(final_lines)

if __name__ == "__main__":
    process_markdown('/home/n30/dotfiles/wiki-wayland-0.99beta.md', '/home/n30/dotfiles/wiki-wayland-1.0.md')
    print("Done formatting.")
