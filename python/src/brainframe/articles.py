import os.path
import requests

from bs4 import BeautifulSoup
from markdownify import markdownify
from tldextract import extract

from brainframe.config import Config


def slugify(instr):
    # replace whitespace with dashes, remove any non-alphanumeric characters from the title
    safe_slug = "".join(x if not x.isspace() else '-' for x in instr.lower() if x.isalnum() or x.isspace())
    # remove any duplicated dashes for the filename
    return "".join(x for (i, x) in enumerate(safe_slug) if (i >= 1 and (safe_slug[i-1] != safe_slug[i] or
                                                                        safe_slug[i] != '-')) or (i == 0))


def get_product(url):
    cfg = Config()
    r = requests.get(url)
    soup = BeautifulSoup(r.content, 'html.parser')
    name = soup.title.string
    with open(cfg.products_md, 'a') as fp:
        fp.write(f"- [{name}]({url})\n")
    print(f"Added {name} to products file")


def get_article(url):
    articlebodies = {
        # key: domain value: lambda function to extract article body
        'opensource.com': lambda body: body.find("div", attrs={'class': 'block-field-blocknodearticlebody'}),
        'medium.com': lambda body: body.find("article")
    }
    domain = extract(url).registered_domain

    r = requests.get(url)
    soup = BeautifulSoup(r.content, 'html.parser')
    tag = articlebodies.get(domain, lambda body: body)(soup.body)
    # TODO: eventually, add support for retrieving images here
    html = str(tag)
    if html:
        try:
            md = markdownify(html, wrap=True)
        except Exception as e:
            md = f"""Error: {str(e)}
            URL: {url}
            DOMAIN: {domain}
            REQ: {str(r)}
            BODY: {soup.body}
            """
            print(md)
            return

        cfg = Config()
        fname = slugify(soup.title.string)
        fname_ext = os.path.join(cfg.articledir, f"{fname}.md")
        os.makedirs(cfg.articledir, exist_ok=True)
        with open(fname_ext, 'w') as fp:
            fp.write(f"[Original Article]({url})\n\n")
            fp.write(md)
            fp.write("\n")

        print(f"article saved to {fname_ext}")
