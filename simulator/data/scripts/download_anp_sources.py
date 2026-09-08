"""Download the raw ANP source files documented in docs/data_report.md.

Uses only the Python 3 standard library. Downloads are idempotent: an
existing destination file is left untouched unless --force is passed.
"""

import argparse
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

SOURCES = {
    "processamento": {
        "url": "https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv",
        "filename": "processamento-petroleo-m3-1990-2025.csv",
    },
    "producao_gasolina_a": {
        "url": "https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv",
        "filename": "producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv",
    },
    "vendas_combustiveis": {
        "url": "https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/vdpb/vendas-derivados-petroleo-e-etanol/vendas-combustiveis-m3-1990-2025.csv",
        "filename": "vendas-combustiveis-m3-1990-2025.csv",
    },
    "capacidade_refino": {
        "url": "https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2026/secao-2/t2-35.xlsx",
        "filename": "t2-35.xlsx",
    },
}

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)


def download_file(url: str, dest: Path, *, force: bool = False) -> Path:
    """Download `url` into `dest`, skipping the download if it already exists.

    The file is streamed into a temporary sibling file and only moved into
    place once the download completes successfully, so a failed download
    never leaves a truncated file at `dest`.
    """
    if dest.exists() and not force:
        print(f"skipping {dest} (already exists, use --force to re-download)")
        return dest

    tmp_path = dest.with_suffix(dest.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request) as response, open(tmp_path, "wb") as tmp_file:
            while True:
                chunk = response.read(1024 * 64)
                if not chunk:
                    break
                tmp_file.write(chunk)
        os.replace(tmp_path, dest)
    except BaseException:
        if tmp_path.exists():
            tmp_path.unlink()
        raise
    return dest


def download_all(dest_dir: Path = None, *, force: bool = False, only: str = None) -> list:
    """Download all (or one, via `only`) ANP source files into `dest_dir`.

    Defaults `dest_dir` to `data/original` relative to this file. Each
    download is attempted independently: a URLError for one source is
    reported and re-raised wrapped with the source name, so callers can
    catch it per-source and keep going with the rest.
    """
    if dest_dir is None:
        dest_dir = Path(__file__).resolve().parent.parent / "original"
    dest_dir.mkdir(parents=True, exist_ok=True)

    names = [only] if only else list(SOURCES.keys())
    results = []
    for name in names:
        source = SOURCES[name]
        dest = dest_dir / source["filename"]
        print(f"downloading {name}: {source['url']} -> {dest}")
        try:
            results.append(download_file(source["url"], dest, force=force))
        except urllib.error.URLError as error:
            raise urllib.error.URLError(f"[{name}] {error.reason}") from error
    print(f"done: {len(results)} file(s) in {dest_dir}")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download the raw ANP source files used to curate data/curated/."
    )
    parser.add_argument(
        "--force", action="store_true", help="re-download even if the destination file already exists"
    )
    parser.add_argument(
        "--only",
        metavar="NAME",
        help=f"download only one named source. Choices: {', '.join(SOURCES.keys())}",
    )
    args = parser.parse_args()

    if args.only is not None and args.only not in SOURCES:
        print(
            f"error: unknown source '{args.only}'. Choices: {', '.join(SOURCES.keys())}",
            file=sys.stderr,
        )
        sys.exit(1)

    names = [args.only] if args.only else list(SOURCES.keys())
    failures = []
    for name in names:
        try:
            download_all(force=args.force, only=name)
        except urllib.error.URLError as error:
            print(f"error: failed to download '{name}': {error.reason}", file=sys.stderr)
            failures.append(name)

    if failures:
        print(f"failed sources: {', '.join(failures)}", file=sys.stderr)
        sys.exit(1)
