#!/bin/bash

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUILD_DIR="build/pdfs"
LOG_FILE="build-logs.txt"
LATEXMK_RUNS=2

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEMP_EXTENSIONS=(
    "aux" "log" "toc" "out" "fls" "fdb_latexmk"
    "synctex.gz" "bbl" "blg" "dvi" "ps" "nav"
    "snm" "vrb" "bcf" "run.xml" "idx" "ilg" "ind"
)


timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo -e "[$(timestamp)] $1" | tee -a "$REPO_ROOT/$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "[$(timestamp)] ${GREEN}✅ $msg${NC}"
    echo "[$(timestamp)] ✅ $msg" >> "$REPO_ROOT/$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "[$(timestamp)] ${RED}❌ $msg${NC}"
    echo "[$(timestamp)] ❌ $msg" >> "$REPO_ROOT/$LOG_FILE"
}

log_info() {
    local msg="$1"
    echo -e "[$(timestamp)] ${BLUE}ℹ️  $msg${NC}"
    echo "[$(timestamp)] ℹ️  $msg" >> "$REPO_ROOT/$LOG_FILE"
}

log_warning() {
    local msg="$1"
    echo -e "[$(timestamp)] ${YELLOW}⚠️  $msg${NC}"
    echo "[$(timestamp)] ⚠️  $msg" >> "$REPO_ROOT/$LOG_FILE"
}


clean_temp_files() {
    local dir="$1"
    for ext in "${TEMP_EXTENSIONS[@]}"; do
        find "$dir" -maxdepth 1 -name "*.$ext" -type f -delete 2>/dev/null
    done
}

extract_errors() {
    local log_file="$1"
    local max_lines="${2:-30}"

    if [ -f "$log_file" ]; then
        echo "--- Error details (first $max_lines lines) ---" >> "$REPO_ROOT/$LOG_FILE"
        grep -A 5 "^!" "$log_file" 2>/dev/null | head -n "$max_lines" >> "$REPO_ROOT/$LOG_FILE"
        grep -i "fatal\|emergency\|no output" "$log_file" 2>/dev/null | head -n 10 >> "$REPO_ROOT/$LOG_FILE"
        echo "--- End of error details ---" >> "$REPO_ROOT/$LOG_FILE"
    fi
}

get_output_path() {
    local tex_file="$1"
    local rel_path="${tex_file#$REPO_ROOT/}"
    local dir_name=$(dirname "$rel_path")

    local subject=$(echo "$dir_name" | cut -d'/' -f1)

    if [ "$subject" == "." ] || [ -z "$subject" ]; then
        subject="misc"
    fi

    echo "$subject"
}

is_main_document() {
    local file="$1"

    if [[ "$file" == *"/parts/"* ]]; then
        return 1
    fi

    if [[ "$file" == *"/build/"* ]]; then
        return 1
    fi

    local basename=$(basename "$file")
    if [[ "$basename" == test* ]]; then
        return 1
    fi

    return 0
}

compile_tex() {
    local tex_file="$1"
    local tex_dir=$(dirname "$tex_file")
    local tex_name=$(basename "$tex_file")
    local pdf_name="${tex_name%.tex}.pdf"
    local log_name="${tex_name%.tex}.log"

    log_info "Compiling: $tex_file"

    local current_dir=$(pwd)

    cd "$tex_dir" || {
        log_error "Cannot change to directory: $tex_dir"
        return 1
    }

    for run in $(seq 1 $LATEXMK_RUNS); do
        log "  Run $run/$LATEXMK_RUNS..."

        if ! latexmk -pdf -f -interaction=nonstopmode -synctex=1 "$tex_name" >> "$REPO_ROOT/$LOG_FILE" 2>&1; then
            if [ "$run" -eq "$LATEXMK_RUNS" ]; then
                log_warning "  Final run had issues - PDF may be incomplete"
            else
                log_warning "  Run $run had issues, retrying..."
            fi
        fi
    done

    if [ -f "$pdf_name" ]; then
        log_success "PDF created: $pdf_name"

        local subject=$(get_output_path "$tex_file")
        local output_dir="$REPO_ROOT/$BUILD_DIR/$subject"

        mkdir -p "$output_dir"

        cp "$pdf_name" "$output_dir/"
        log_info "Copied to: $output_dir/$pdf_name"

        rm "$pdf_name"
        log_info "Removed source PDF from: $tex_dir"
    else
        log_error "PDF not created: $pdf_name"
        extract_errors "$log_name" 30
        clean_temp_files "."
        cd "$current_dir"
        return 1
    fi

    clean_temp_files "."

    cd "$current_dir"
    return 0
}

main() {
    echo "==============================================================================" > "$REPO_ROOT/$LOG_FILE"
    echo "CDS-hub LaTeX Build Log" >> "$REPO_ROOT/$LOG_FILE"
    echo "Started at: $(timestamp)" >> "$REPO_ROOT/$LOG_FILE"
    echo "==============================================================================" >> "$REPO_ROOT/$LOG_FILE"
    echo "" >> "$REPO_ROOT/$LOG_FILE"

    if ! command -v latexmk &> /dev/null; then
        log_error "latexmk not found. Please install TeX Live."
        exit 1
    fi

    if [ ! -f "$REPO_ROOT/stylefile.sty" ]; then
        log_warning "stylefile.sty not found in repository root - compilation might fail"
    fi

    log_info "Repository root: $REPO_ROOT"
    log_info "Build directory: $BUILD_DIR"
    log_info "LaTeX runs per file: $LATEXMK_RUNS"
    echo ""

    mkdir -p "$REPO_ROOT/$BUILD_DIR"

    log_info "Searching for .tex files..."

    TEX_FILES=()
    while IFS= read -r -d '' file; do
        if is_main_document "$file"; then
            TEX_FILES+=("$file")
        fi
    done < <(find "$REPO_ROOT" -name "*.tex" -type f -print0 2>/dev/null)

    if [ ${#TEX_FILES[@]} -eq 0 ]; then
        log_warning "No main .tex files found to compile"
        echo ""
        log_info "Build completed with 0 files"
        exit 0
    fi

    log_info "Found ${#TEX_FILES[@]} main .tex file(s) to compile"
    echo ""

    for tex_file in "${TEX_FILES[@]}"; do
        echo "--------------------------------------------------------------------------"
        if compile_tex "$tex_file"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_FILES+=("$tex_file")
        fi
        echo ""
    done

    echo "=============================================================================="
    log_info "BUILD SUMMARY"
    echo "=============================================================================="
    log_success "Successful: $SUCCESS_COUNT"

    if [ $FAIL_COUNT -gt 0 ]; then
        log_error "Failed: $FAIL_COUNT"
        echo ""
        log_error "Failed files:"
        for file in "${FAILED_FILES[@]}"; do
            echo "  - $file" | tee -a "$REPO_ROOT/$LOG_FILE"
        done
    fi

    echo ""
    log_info "Build finished at: $(timestamp)"

    if [ -d "$REPO_ROOT/$BUILD_DIR" ]; then
        echo ""
        log_info "Generated PDFs:"
        find "$REPO_ROOT/$BUILD_DIR" -name "*.pdf" -type f | while read pdf; do
            size=$(du -h "$pdf" | cut -f1)
            rel_path="${pdf#$REPO_ROOT/}"
            echo "  📄 $rel_path ($size)" | tee -a "$REPO_ROOT/$LOG_FILE"
        done
    fi

    echo "=============================================================================="

    if [ $FAIL_COUNT -gt 0 ]; then
        log_error "Build failed with $FAIL_COUNT error(s)"
        exit 1
    else
        log_success "Build completed successfully!"
        exit 0
    fi
}

main "$@"