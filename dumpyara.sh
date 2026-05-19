#!/usr/bin/env bash

echo_i() { echo -e "\n\033[1;36m==> $1\033[0m\n"; }
echo_w() { echo -e "\033[1;33m $1\033[0m"; }
echo_e() { echo -e "\n\033[1;31m $1\033[0m\n"; }

cat README.md

if [[ -n $GIT_OAUTH_TOKEN ]]; then
    GITPUSH=(git push https://"$GIT_OAUTH_TOKEN"@github.com/EncomDumps/"${repo,,}".git "$branch")
    git init
    git config user.email EncomDumps@github.com
    git config user.name EncomDumps
    git config commit.gpgsign false
    curl -s -X POST -H "Authorization: token ${GIT_OAUTH_TOKEN}" -d '{ "name": "'"$repo"'" }' "https://api.github.com/orgs/EncomDumps/repos" #create new repo
    curl -s -X PUT -H "Authorization: token ${GIT_OAUTH_TOKEN}" -H "Accept: application/vnd.github.mercy-preview+json" -d '{ "names": ["'"$manufacturer"'","'"$platform"'","'"$top_codename"'"]}' "https://api.github.com/repos/EncomDumps/${repo}/topics"
    git remote add origin https://github.com/EncomDumps/"${repo,,}".git
    git checkout -b "$branch"
    find . -size +97M -printf '%P\n' -o -name "*sensetime*" -printf '%P\n' -o -name "*.lic" -printf '%P\n' >| .gitignore
    # Compress large files in parallel
    compress_file() {
        local file_path="$1"
        local max_size=$((99 * 1024 * 1024)) # 99MB
        if [ -f "$file_path" ]; then
            local compressed_file="${file_path}.zst"
            zstdmt --ultra -22 --long -M512 "$file_path" -o "$compressed_file"
            if [ $(stat -c%s "$compressed_file") -le $max_size ]; then
                echo "$compressed_file"
            else
                rm -f "$compressed_file"
            fi
        fi
    }
    export -f compress_file
    # Process files in parallel and collect compressed filenames
    cat .gitignore | xargs -P $(nproc) -I {} bash -c 'compress_file "{}"' > compressed_files.txt
    echo "fs_config_dirs" >> .gitignore
    echo "fs_config_files" >> .gitignore
    # Create extraction script
    cat > extract_files.sh << 'EOF'
#!/bin/bash

while IFS= read -r file; do
    unzstd "$file"
done < compressed_files.txt
EOF
    chmod +x extract_files.sh
    git add --all
    git reset HEAD -- system/ system_ext/ vendor/ product/ odm/ my_*/
    git commit -asm "Add extras for ${description}" && "${GITPUSH[@]}"
    git add system/system/app/ || git add system/app/
    git commit -asm "Add system app for ${description}" && "${GITPUSH[@]}"
    git add system/system/priv-app/ || git add system/priv-app/
    git commit -asm "Add system priv-app for ${description}" && "${GITPUSH[@]}"
    git add system/vendor
    git commit -asm "Add system/vendor for ${description}" && "${GITPUSH[@]}"
    git add system/
    git commit -asm "Add system for ${description}" && "${GITPUSH[@]}"
    git add system_ext/app/
    git commit -asm "Add system_ext app for ${description}" && "${GITPUSH[@]}"
    git add system_ext/priv-app/
    git commit -asm "Add system_ext priv-app for ${description}" && "${GITPUSH[@]}"
    git add system_ext/
    git commit -asm "Add system_ext for ${description}" && "${GITPUSH[@]}"
    git add product/app/
    git commit -asm "Add product app for ${description}" && "${GITPUSH[@]}"
    git add product/priv-app/
    git commit -asm "Add product priv-app for ${description}" && "${GITPUSH[@]}"
    git add product/
    git commit -asm "Add product for ${description}" && "${GITPUSH[@]}"
    git add vendor/
    git commit -asm "Add vendor for ${description}" && "${GITPUSH[@]}"
    git add odm/
    git commit -asm "Add odm for ${description}" && "${GITPUSH[@]}"
    if ls -d my_*/ >/dev/null 2>&1; then
        for oplus_dir in my_*/; do
            git add "${oplus_dir}"
            git commit -asm "Add ${oplus_dir} for ${description}" && "${GITPUSH[@]}"
        done
    fi
else
    echo_i "Done..."
    exit 1
fi
