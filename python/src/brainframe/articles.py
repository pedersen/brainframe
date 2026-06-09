import os.path

from markdownify import markdownify
from selenium import webdriver
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.by import By
from tldextract import extract

from brainframe.config import Config

# Youtube : https://www.geeksforgeeks.org/pytube-python-library-download-youtube-videos/
# Zotero : https://github.com/urschrei/pyzotero
# Beautiful Soup 4: https://www.crummy.com/software/BeautifulSoup/bs4/doc/
# Pocket : https://getpocket.com/developer/


def slugify(instr: str):
    # replace whitespace with dashes, remove any non-alphanumeric characters from the title
    safe_slug = "".join(x if not x.isspace() else '-' for x in instr.lower() if x.isalnum() or x.isspace())
    # remove any duplicated dashes for the filename
    return "".join(x for (i, x) in enumerate(safe_slug) if (i >= 1 and (safe_slug[i-1] != safe_slug[i] or
                                                                        safe_slug[i] != '-')) or (i == 0))


def get_product(url: str, driver: webdriver.Firefox = None):
    cfg = Config()
    driver.get(url)
    wait = WebDriverWait(driver, 10)
    wait.until(lambda x: driver.title.strip() != '')
    name = driver.title
    with open(cfg.products_md, 'a') as fp:
        fp.write(f"- [{name}]({url})\n")
    print(f"Added {name} to products file")


def gitmark(url: str, driver: webdriver.Firefox = None):
    cfg = Config()
    driver.get(url)
    wait = WebDriverWait(driver, 10)
    wait.until(lambda x: driver.title.strip() != '')
    name = driver.title
    with open(cfg.gitmarks_md, 'a') as fp:
        fp.write(f"- [{name}]({url})\n")
    print(f"Added {name} to gitmarks file")

def get_article(url: str, driver: webdriver.Firefox = None):
    articlebodies = {
        # key: domain value: lambda function to extract article body
        'opensource.com': lambda: driver.find_element(By.XPATH,
                                                      '//div[contains(@class, "block-field-blocknodearticlebody")]'),
        'medium.com': lambda: driver.find_element(By.NAME, "article")
    }
    domain = extract(url).registered_domain

    driver.get(url)
    scanfunc = articlebodies.get(domain, lambda: driver.find_element(By.NAME, "body"))
    html = scanfunc().get_attribute("innerHTML")
    md = markdownify(html, wrap=True)
    cfg = Config()
    fname = slugify(driver.title)
    fname_ext = os.path.join(cfg.articledir, f"{fname}.md")
    os.makedirs(cfg.articledir, exist_ok=True)
    with open(fname_ext, 'w') as fp:
        fp.write(f"[Original Article]({url})\n\n")
        fp.write(md)
        fp.write("\n")

    print(f"article saved to {fname_ext}")
