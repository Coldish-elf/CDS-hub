#!/bin/bash

set -e

BUILD_DIR="build/pdfs"
OUTPUT_FILE="$BUILD_DIR/index.html"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

format_title() {
    local name="$1"
    echo "$name" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

get_file_size() {
    local file="$1"
    local size
    if [[ "$OSTYPE" == "darwin"* ]]; then
        size=$(stat -f%z "$file" 2>/dev/null)
    else
        size=$(stat --printf=%s "$file" 2>/dev/null)
    fi

    if [ "$size" -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $size/1048576}") MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $size/1024}") KB"
    else
        echo "$size B"
    fi
}

get_file_date() {
    local file="$1"
    local pdf_name=$(basename "$file" .pdf)
    local original_tex

    original_tex=$(find "$REPO_ROOT" -name "${pdf_name}.tex" -type f ! -path "*/parts/*" ! -path "*/build/*" 2>/dev/null | head -1)

    if [ -n "$original_tex" ] && command -v git &> /dev/null; then
        local git_date=$(git log -1 --format="%ci" -- "$original_tex" 2>/dev/null | cut -d' ' -f1)
        if [ -n "$git_date" ]; then
            echo "$git_date"
            return
        fi
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%Sm -t%Y-%m-%d "$file" 2>/dev/null || echo "—"
    else
        date -r "$file" +%Y-%m-%d 2>/dev/null || echo "—"
    fi
}

get_doc_icon() {
    local name="$1"
    case "${name,,}" in
        *colloquium*|*colloq*|*коллоквиум*|*коллок*) echo "📝" ;;
        *lecture*|*лекция*|*лекции*) echo "📖" ;;
        *consultation*|*разбор*|*консультация*) echo "🔧" ;;
        *cheatsheet*|*шпаргалка*|*шпора*) echo "📜" ;;
        *) echo "📄" ;;
    esac
}

get_subject_icon() {
    local name="$1"
    case "${name,,}" in
        *math*|*discrete*|*матем*|*дискрет*) echo "🔢" ;;
        *algebra*|*linear*|*алгебр*|*линейн*) echo "📐" ;;
        *analysis*|*calculus*|*анализ*|*матан*) echo "📊" ;;
        *programming*|*code*|*програм*) echo "💻" ;;
        *geometry*|*геометр*) echo "📐" ;;
        *statistics*|*probability*|*статист*|*вероятн*) echo "📈" ;;
        *) echo "📚" ;;
    esac
}

generate_html() {
    echo "Generating GitHub Pages..."

    if [ ! -d "$BUILD_DIR" ]; then
        echo "Error: Directory $BUILD_DIR does not exist"
        echo "Run ./scripts/build.sh first"
        exit 1
    fi

    local subject_count=0
    local document_count=0
    local last_update=""

    for subject_dir in "$BUILD_DIR"/*/; do
        [ -d "$subject_dir" ] || continue
        local pdf_count=$(find "$subject_dir" -maxdepth 1 -name "*.pdf" -type f 2>/dev/null | wc -l)
        [ "$pdf_count" -eq 0 ] && continue
        subject_count=$((subject_count + 1))
        document_count=$((document_count + pdf_count))
    done

    for pdf_file in "$BUILD_DIR"/*/*.pdf; do
        [ -f "$pdf_file" ] || continue
        local pdf_date=$(get_file_date "$pdf_file")
        if [ -z "$last_update" ] || [[ "$pdf_date" > "$last_update" ]]; then
            last_update="$pdf_date"
        fi
    done

    cat > "$OUTPUT_FILE" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="ru" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="CDS-hub — Study Materials">
    <title>CDS-hub — Study Materials</title>
    <link href="https://cdn.jsdelivr.net/npm/daisyui@4.12.14/dist/full.min.css" rel="stylesheet" type="text/css" />
    <script src="https://cdn.tailwindcss.com"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {}
            }
        }
    </script>
    <style>
        [x-cloak] { display: none !important; }
    </style>
</head>
<body class="min-h-screen bg-base-100 transition-colors duration-300" x-data="app()" x-init="init()">

    <!-- Navbar -->
    <div class="navbar bg-base-200 shadow-lg sticky top-0 z-50">
        <div class="navbar-start">
            <div class="dropdown">
                <div tabindex="0" role="button" class="btn btn-ghost lg:hidden" @click="mobileMenuOpen = !mobileMenuOpen">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
                    </svg>
                </div>
                <ul tabindex="0" class="menu menu-sm dropdown-content bg-base-200 rounded-box z-[1] mt-3 w-52 p-2 shadow" x-show="mobileMenuOpen" x-cloak @click="mobileMenuOpen = false" @click.outside="mobileMenuOpen = false">
                    <li><a href="https://github.com/Coldish-elf/CDS-hub" target="_blank" rel="noopener">GitHub</a></li>
                </ul>
            </div>
            <a class="btn btn-ghost text-xl gap-2" href="#">
                <span class="font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">CDS-hub</span>
            </a>
        </div>

        <div class="navbar-center hidden lg:flex">
            <div class="form-control">
                <input type="text"
                       placeholder="Поиск документа..."
                       class="input input-bordered w-80"
                       x-model="searchQuery"
                       @input="filterDocuments()">
            </div>
        </div>

        <div class="navbar-end gap-2">
            <button class="btn btn-ghost btn-circle" @click="toggleDarkMode()" :aria-label="darkMode ? 'Светлая тема' : 'Тёмная тема'">
                <span x-text="darkMode ? '☀️' : '🌙'" class="text-xl"></span>
            </button>
            <a href="https://github.com/Coldish-elf/CDS-hub" target="_blank" rel="noopener" class="btn btn-ghost hidden lg:flex gap-2">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
                </svg>
                GitHub
            </a>
        </div>
    </div>

    <!-- Mobile Search -->
    <div class="lg:hidden p-4 bg-base-200">
        <input type="text"
               placeholder="Поиск документа..."
               class="input input-bordered w-full"
               x-model="searchQuery"
               @input="filterDocuments()">
    </div>

    <main class="container mx-auto px-4 py-8 max-w-7xl">

        <!-- Stats -->
        <div class="stats stats-vertical lg:stats-horizontal shadow w-full mb-8 bg-base-200">
            <div class="stat">
                <div class="stat-figure text-primary">📂</div>
                <div class="stat-title">Предметов</div>
HTMLHEAD

    echo "                <div class=\"stat-value text-primary\">$subject_count</div>" >> "$OUTPUT_FILE"

    cat >> "$OUTPUT_FILE" << 'STATS2'
            </div>
            <div class="stat">
                <div class="stat-figure text-secondary">📄</div>
                <div class="stat-title">Документов</div>
STATS2

    echo "                <div class=\"stat-value text-secondary\">$document_count</div>" >> "$OUTPUT_FILE"

    cat >> "$OUTPUT_FILE" << 'STATS3'
            </div>
            <div class="stat">
                <div class="stat-figure text-accent">📅</div>
                <div class="stat-title">Обновлено</div>
STATS3

    echo "                <div class=\"stat-value text-accent text-lg\">${last_update:-—}</div>" >> "$OUTPUT_FILE"

    cat >> "$OUTPUT_FILE" << 'STATS_END'
            </div>
        </div>

        <!-- Content -->
        <div id="content">
STATS_END

    for subject_dir in "$BUILD_DIR"/*/; do
        [ -d "$subject_dir" ] || continue

        local subject_name=$(basename "$subject_dir")
        local subject_title=$(format_title "$subject_name")
        local subject_icon=$(get_subject_icon "$subject_name")

        local pdf_count=$(find "$subject_dir" -maxdepth 1 -name "*.pdf" -type f 2>/dev/null | wc -l)
        [ "$pdf_count" -eq 0 ] && continue

        cat >> "$OUTPUT_FILE" << SECTION_START

            <!-- Subject: $subject_title -->
            <section class="mb-12 subject-section" data-subject="$subject_name">
                <div class="flex items-center gap-3 mb-6 pb-3 border-b border-base-300">
                    <span class="text-2xl">$subject_icon</span>
                    <h2 class="text-2xl font-bold">$subject_title</h2>
                    <div class="badge badge-primary">$pdf_count</div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
SECTION_START

        for pdf_file in "$subject_dir"*.pdf; do
            [ -f "$pdf_file" ] || continue

            local pdf_name=$(basename "$pdf_file" .pdf)
            local pdf_title=$(format_title "$pdf_name")
            local pdf_size=$(get_file_size "$pdf_file")
            local pdf_date=$(get_file_date "$pdf_file")
            local pdf_path="${pdf_file#$BUILD_DIR/}"
            local doc_icon=$(get_doc_icon "$pdf_name")

            cat >> "$OUTPUT_FILE" << CARD

                    <!-- Document: $pdf_title -->
                    <div class="card bg-base-200 shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1 doc-card"
                         data-title="$pdf_title"
                         data-name="$pdf_name"
                         x-show="filterVisible(\$el)"
                         x-transition>
                        <div class="card-body">
                            <div class="text-2xl mb-2">$doc_icon</div>
                            <h3 class="card-title text-lg">$pdf_title</h3>
                            <div class="flex flex-wrap gap-4 text-sm opacity-70 my-2">
                                <span>$pdf_size</span>
                                <span>$pdf_date</span>
                            </div>
                            <div class="card-actions justify-end mt-4">
                                <a href="$pdf_path" target="_blank" class="btn btn-primary btn-sm">
                                    📖 Открыть
                                </a>
                                <a href="$pdf_path" download class="btn btn-outline btn-sm">
                                    ⬇️ Скачать
                                </a>
                            </div>
                        </div>
                    </div>
CARD
        done

        cat >> "$OUTPUT_FILE" << 'SECTION_END'
                </div>
            </section>
SECTION_END
    done

    if [ $document_count -eq 0 ]; then
        cat >> "$OUTPUT_FILE" << 'EMPTY'

            <div class="hero min-h-[50vh]">
                <div class="hero-content text-center">
                    <div class="max-w-md">
                        <div class="text-6xl mb-4">📭</div>
                        <h2 class="text-2xl font-bold">Документы не найдены</h2>
                        <p class="py-4 opacity-70">Запустите build скрипт для генерации PDF файлов</p>
                    </div>
                </div>
            </div>
EMPTY
    fi

    cat >> "$OUTPUT_FILE" << 'HTMLFOOT'
        </div>

        <!-- No Results -->
        <div class="hero min-h-[30vh]" x-show="noResults" x-cloak x-transition>
            <div class="hero-content text-center">
                <div class="max-w-md">
                    <div class="text-5xl mb-4">🔍</div>
                    <h3 class="text-xl font-bold">Ничего не найдено</h3>
                    <p class="py-2 opacity-70">Попробуйте изменить поисковый запрос</p>
                </div>
            </div>
        </div>

    </main>

    <!-- Footer -->
    <footer class="footer footer-center p-4 bg-base-200 text-base-content mt-8">
        <aside>
            <p>© 2026 CDS-hub</p>
        </aside>
    </footer>

    <script>
        function app() {
            return {
                searchQuery: '',
                darkMode: true,
                mobileMenuOpen: false,
                noResults: false,

                init() {
                    this.loadTheme();
                    this.applyTheme();
                },

                toggleDarkMode() {
                    this.darkMode = !this.darkMode;
                    this.saveTheme();
                    this.applyTheme();
                },

                loadTheme() {
                    try {
                        const stored = localStorage.getItem('cds-hub-theme');
                        if (stored) {
                            this.darkMode = stored === 'dark';
                        } else {
                            this.darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
                        }
                    } catch (e) {
                        this.darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
                    }
                },

                saveTheme() {
                    try {
                        localStorage.setItem('cds-hub-theme', this.darkMode ? 'dark' : 'light');
                    } catch (e) {
                        console.warn('Cannot save theme preference');
                    }
                },

                applyTheme() {
                    if (this.darkMode) {
                        document.documentElement.classList.add('dark');
                        document.documentElement.setAttribute('data-theme', 'dark');
                    } else {
                        document.documentElement.classList.remove('dark');
                        document.documentElement.setAttribute('data-theme', 'light');
                    }
                },

                filterVisible(el) {
                    if (!this.searchQuery.trim()) return true;
                    const query = this.searchQuery.toLowerCase();
                    const title = el.dataset.title?.toLowerCase() || '';
                    const name = el.dataset.name?.toLowerCase() || '';

                    const section = el.closest('.subject-section');
                    const subject = section?.dataset.subject?.toLowerCase() || '';

                    return title.includes(query) || name.includes(query) || subject.includes(query);
                },

                filterDocuments() {
                    this.$nextTick(() => {
                        const cards = document.querySelectorAll('.doc-card');
                        const sections = document.querySelectorAll('.subject-section');
                        let visibleCount = 0;

                        cards.forEach(card => {
                            const isVisible = this.filterVisible(card);
                            if (isVisible) visibleCount++;
                        });

                        sections.forEach(section => {
                            const visibleCards = Array.from(section.querySelectorAll('.doc-card')).filter(card => this.filterVisible(card));
                            section.style.display = visibleCards.length > 0 ? 'block' : 'none';
                        });

                        this.noResults = visibleCount === 0 && this.searchQuery.trim() !== '';
                    });
                }
            }
        }
    </script>
</body>
</html>
HTMLFOOT

    echo "Generated: $OUTPUT_FILE"
    echo "Subjects: $subject_count"
    echo "Documents: $document_count"
}

generate_html