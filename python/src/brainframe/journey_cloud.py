import datetime
import json
import os
import zipfile

from markdownify import markdownify

from brainframe.config import Config


# 1587605073530
def extract_one_entry(archive: zipfile.ZipFile, fname: str):
    with archive.open(fname) as journal:
        d = json.loads(journal.read())
        journal = {}
        delkeys = ['preview_text', 'lat', 'lon', 'weather', 'id', 'date_modified', 'type', 'text', 'date_journal',
                   'timezone']
        for key in d.keys():
            if not d[key]:
                delkeys.append(key)
        text = markdownify(journal.get('text', ''), wrap=True)
        text = text.replace('\\n', '\n').replace("\\\'", "'")
        journal['text'] = text

        dt = datetime.datetime.fromtimestamp(d['date_journal']/1000.0)
        journal['date'] = f"{dt.year}-{dt.month:02d}-{dt.day:02d}"

        for key in delkeys:
            if key in d:
                del d[key]
        print(str(d))


def import_journey(zipfilename:str):
    zipfilename = os.path.expanduser(zipfilename)
    if not os.path.exists(zipfilename):
        print(f"Error: {zipfilename} does not exist")
        return
    archive = zipfile.ZipFile(zipfilename)
    for fname in archive.namelist():
        #print(f"{fname}")
        pass

    extract_one_entry(archive, '1587605073530-k7vjfgp6n3c2v5u3.json')
