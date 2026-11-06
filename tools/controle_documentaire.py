import csv,glob,os,re,collections
"""Contrôle documentaire de Folie Mécanique (lecture seule). Usage : python3 tools/controle_documentaire.py depuis la racine du dépôt."""
res={}
# 1 liens
bad=[];n=0
mds=[f for f in glob.glob("**/*.md",recursive=True) if not f.startswith(("game/addons","archive/prototype"))]
for f in mds:
    for m in re.finditer(r"\]\(([^)\s#]+)\)",open(f,encoding='utf-8',errors='ignore').read()):
        t=m.group(1)
        if t.startswith(("http","mailto","res:","user:")): continue
        n+=1
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f),t))): bad.append((f,t))
res["liens"]=(len(mds),n,bad)
# index vs fichiers
idx=open("data/master/INDEX.md",encoding='utf-8').read()
listed=set(re.findall(r"`([a-z0-9_]+\.csv)`",idx))
present={os.path.basename(f) for f in glob.glob("data/master/*.csv")}
res["index"]=(sorted(present-listed),sorted(listed-present))
# ids dupliqués / vides
dup=[];noid=[];empty=[]
for f in sorted(glob.glob("data/master/*.csv")):
    try: R=list(csv.reader(open(f,encoding='utf-8')))
    except Exception as e: empty.append((f,str(e)));continue
    if not R: continue
    h=R[0]; rows=R[1:]
    idc=[i for i,c in enumerate(h) if c.strip().lower().startswith("id")]
    for i in idc[:1]:
        vals=[r[i] for r in rows if len(r)>i]
        c=collections.Counter(v for v in vals if v.strip())
        d=[k for k,v in c.items() if v>1]
        if d: dup.append((os.path.basename(f),h[i],d[:5],len(d)))
        e=sum(1 for v in vals if not v.strip())
        if e: noid.append((os.path.basename(f),h[i],e))
    if not idc: noid.append((os.path.basename(f),"(aucune colonne ID)",len(rows)))
res["dup"]=dup;res["noid"]=noid;res["err"]=empty
# bible ids
b=open("docs/lore/01_BIBLE_FOUNDATION",encoding='utf-8').read()
ids=re.findall(r"Identifiant\s*:\s*([A-Z]{2,5}-\d{3})",b)
c=collections.Counter(ids); res["bible"]=(len(ids),[k for k,v in c.items() if v>1])
# armes sans source
R=list(csv.DictReader(open("data/master/armes_historiques.csv",encoding='utf-8')))
res["armes"]=(len(R),sum(1 for r in R if r["Sources historiques"].startswith("À sourcer")))
# decisions: ids dup
d=open("docs/DECISIONS.md",encoding='utf-8').read()
dd=re.findall(r"\| (DEC-\d{3}) \|",d); c=collections.Counter(dd)
res["dec"]=(len(dd),[k for k,v in c.items() if v>1], [f"DEC-{i:03d}" for i in range(1,max(int(x[4:]) for x in dd)+1) if f"DEC-{i:03d}" not in dd])
# unités: colonnes mélangeant (L)/(l)/litres
res["registre_chemins"]=[l for l in re.findall(r"\[`([^`]+)`\]\(\.\./([^)]+)\)",open("docs/DOCUMENT_REGISTRY.md",encoding='utf-8').read()) if not os.path.exists(l[1])]
for k,v in res.items(): print(k,"=>",v)
