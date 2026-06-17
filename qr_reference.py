# ============================================================================
# VERIFIED REFERENCE QR ENCODER  (Python)
# ----------------------------------------------------------------------------
# This encoder is specialized for EXACTLY 48 numeric digits (a BitLocker
# recovery key with dashes removed). It produces a QR Version 2 (25x25),
# EC level M, mask 0.
#
# This implementation has been TESTED: 20/20 random 48-digit keys round-trip
# correctly through an independent decoder (pyzbar). It is KNOWN-GOOD.
#
# GOAL: The PowerShell script "Show-BitLockerBarcode.ps1" contains a port of
# this exact logic, but its QR output does NOT scan. Use this file as the
# reference of truth. Make the PowerShell QR matrix match what this code
# produces (module-for-module), and verify by decoding.
#
# To verify here:
#   pip install qrcode pillow pyzbar --break-system-packages
#   sudo apt-get install -y libzbar0
#   python3 qr_reference.py
# ============================================================================

def gf_tables():
    exp=[0]*512; log=[0]*256
    x=1
    for i in range(255):
        exp[i]=x; log[x]=i
        x<<=1
        if x & 0x100: x^=0x11D
    for i in range(255,512): exp[i]=exp[i-255]
    return exp,log
EXP,LOG=gf_tables()

def gmul(a,b):
    if a==0 or b==0: return 0
    return EXP[(LOG[a]+LOG[b])%255]

def gen_poly(n):
    g=[1]
    for i in range(n):
        ng=[0]*(len(g)+1)
        for j in range(len(g)):
            ng[j]^=g[j]
            ng[j+1]^=gmul(g[j],EXP[i])
        g=ng
    return g

def rs_ec(data, ncodewords):
    g=gen_poly(ncodewords)
    res=[0]*(len(data)+ncodewords)
    res[:len(data)]=data[:]
    for i in range(len(data)):
        coef=res[i]
        if coef!=0:
            for j in range(len(g)):
                res[i+j]^=gmul(g[j],coef)
    return res[len(data):]

def encode_numeric_48(digits):
    assert len(digits)==48 and digits.isdigit()
    bits=[]
    def put(val,n):
        for i in range(n-1,-1,-1): bits.append((val>>i)&1)
    put(0b0001,4)            # numeric mode
    put(48,10)               # count, 10 bits for v1-9
    for i in range(0,48,3):
        put(int(digits[i:i+3]),10)
    data_cw=28
    cap=data_cw*8
    if len(bits)+4<=cap: put(0,4)
    while len(bits)%8!=0: bits.append(0)
    codewords=[int(''.join(map(str,bits[i:i+8])),2) for i in range(0,len(bits),8)]
    pads=[0xEC,0x11]; k=0
    while len(codewords)<data_cw:
        codewords.append(pads[k%2]); k+=1
    ec=rs_ec(codewords,16)
    return codewords+ec   # 44 codewords

def make_matrix(all_codewords, mask_id=0):
    size=25
    m=[[None]*size for _ in range(size)]
    res=[[False]*size for _ in range(size)]
    def place_finder(r,c):
        for dr in range(-1,8):
            for dc in range(-1,8):
                rr,cc=r+dr,c+dc
                if 0<=rr<size and 0<=cc<size:
                    if (dr in(0,6) and 0<=dc<=6) or (dc in(0,6) and 0<=dr<=6):
                        v=1
                    elif 2<=dr<=4 and 2<=dc<=4:
                        v=1
                    else:
                        v=0
                    m[rr][cc]=v; res[rr][cc]=True
    place_finder(0,0); place_finder(0,size-7); place_finder(size-7,0)
    for i in range(size):
        if m[6][i] is None: m[6][i]=1 if i%2==0 else 0; res[6][i]=True
        if m[i][6] is None: m[i][6]=1 if i%2==0 else 0; res[i][6]=True
    ar,ac=18,18
    for dr in range(-2,3):
        for dc in range(-2,3):
            rr,cc=ar+dr,ac+dc
            if max(abs(dr),abs(dc))==2 or (dr==0 and dc==0): v=1
            else: v=0
            m[rr][cc]=v; res[rr][cc]=True
    m[size-8][8]=1; res[size-8][8]=True
    for i in range(9):
        for (r,c) in [(8,i),(i,8)]:
            if 0<=r<size and 0<=c<size: res[r][c]=True
    for i in range(8):
        res[8][size-1-i]=True
        res[size-1-i][8]=True
    res[8][8]=True
    def mask_fn(r,c):
        return (r+c)%2==0  # mask 0
    bits=[]
    for cw in all_codewords:
        for i in range(7,-1,-1): bits.append((cw>>i)&1)
    bitidx=0
    col=size-1
    up=True
    while col>0:
        if col==6: col-=1
        rows=range(size-1,-1,-1) if up else range(size)
        for r in rows:
            for c in (col,col-1):
                if not res[r][c]:
                    b=bits[bitidx] if bitidx<len(bits) else 0
                    bitidx+=1
                    if mask_fn(r,c): b^=1
                    m[r][c]=b
        up=not up
        col-=2
    # format info: level M (00) + mask 0 (000) -> final 15-bit string
    fmt="101010000010010"
    fb=[int(x) for x in fmt]
    coords1=[(8,0),(8,1),(8,2),(8,3),(8,4),(8,5),(8,7),(8,8),(7,8),(5,8),(4,8),(3,8),(2,8),(1,8),(0,8)]
    for i,(r,c) in enumerate(coords1): m[r][c]=fb[i]
    for i in range(7):
        m[size-1-i][8]=fb[i]
    for i in range(8):
        m[8][size-8+i]=fb[7+i]
    return m

def render_png(m,path,scale=12,border=4):
    from PIL import Image
    size=len(m); full=size+2*border
    img=Image.new("1",(full*scale,full*scale),1)
    px=img.load()
    for r in range(size):
        for c in range(size):
            if m[r][c]==1:
                for y in range((r+border)*scale,(r+border+1)*scale):
                    for x in range((c+border)*scale,(c+border+1)*scale):
                        px[x,y]=0
    img.save(path)

if __name__=="__main__":
    import random
    # round-trip self-test
    try:
        from pyzbar.pyzbar import decode
        from PIL import Image
        ok=0
        for _ in range(20):
            key=''.join(random.choice('0123456789') for _ in range(48))
            m=make_matrix(encode_numeric_48(key),0)
            render_png(m,"/tmp/_qr.png")
            out=decode(Image.open("/tmp/_qr.png"))
            if out and out[0].data.decode()==key: ok+=1
        print(f"Round-trip: {ok}/20 decoded correctly")
    except ImportError:
        print("Install: pip install qrcode pillow pyzbar --break-system-packages ; apt-get install -y libzbar0")
    # also dump the matrix for a fixed key so PowerShell output can be compared
    key="002130563959533643315590484044259380247291123563"
    m=make_matrix(encode_numeric_48(key),0)
    print("Matrix for key", key, "(1=black module):")
    for row in m:
        print(''.join('#' if v==1 else '.' for v in row))
