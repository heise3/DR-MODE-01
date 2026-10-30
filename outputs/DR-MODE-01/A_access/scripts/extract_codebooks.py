from pathlib import Path
from html.parser import HTMLParser
class Text(HTMLParser):
    def __init__(self):
        super().__init__(); self.t=[]; self.skip=0
    def handle_starttag(self,tag,attrs):
        if tag in ('script','style'): self.skip+=1
        if tag in ('p','h1','h2','h3','h4','tr','li'):self.t.append('\n')
    def handle_endtag(self,tag):
        if tag in ('script','style'):self.skip=max(self.skip-1,0)
        if tag in ('p','h1','h2','h3','h4','tr','li','dd','dt'):self.t.append('\n')
    def handle_data(self,data):
        if not self.skip:self.t.append(data)
for p in Path('outputs/DR-MODE-01/A_access/codebooks').glob('*.htm'):
    x=Text();x.feed(p.read_text())
    s='\n'.join(' '.join(a.split()) for a in ''.join(x.t).splitlines() if a.strip())
    p.with_suffix('.txt').write_text(s+'\n')
