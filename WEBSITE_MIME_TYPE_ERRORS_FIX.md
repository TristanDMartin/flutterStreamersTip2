# Website MIME Type Errors Fix Guide

## 🔴 **Error Summary**

Your Next.js website at `localhost:3000` is experiencing:
1. **MIME Type Errors**: CSS/JS files served as `text/plain` instead of proper types
2. **404 Errors**: Next.js static files not found (`_next/static/*`)
3. **CORS Errors**: API calls blocked
4. **Videos Not Appearing**: Likely due to failed resource loading

---

## 🔍 **Root Causes**

### 1. **Server Configuration Issue**
- Web server (nginx, Apache, or Next.js dev server) not configured with correct MIME types
- Static files not being served from correct directory

### 2. **Next.js Build Issue**
- `.next` build directory missing or incomplete
- Static assets not generated properly

### 3. **CORS Configuration**
- API server (`api.travelarrow.io`) not allowing requests from `localhost:3000`

---

## ✅ **Solutions**

### **Solution 1: Fix Next.js Dev Server**

If using `next dev`:

```bash
# Stop current server (Ctrl+C)
# Clear .next directory
rm -rf .next

# Reinstall dependencies
npm install
# or
yarn install

# Rebuild and restart
npm run dev
# or
yarn dev
```

### **Solution 2: Check Next.js Configuration**

Create/update `next.config.js`:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Ensure static files are served correctly
  assetPrefix: process.env.NODE_ENV === 'production' ? '' : '',
  
  // Headers for proper MIME types
  async headers() {
    return [
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Content-Type',
            value: 'application/javascript; charset=utf-8',
          },
        ],
      },
      {
        source: '/_next/static/css/:path*',
        headers: [
          {
            key: 'Content-Type',
            value: 'text/css; charset=utf-8',
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
```

### **Solution 3: Fix CORS on API Server**

If you control `api.travelarrow.io`, add CORS headers:

```javascript
// Express.js example
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', 'http://localhost:3000');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});
```

### **Solution 4: Use Next.js Custom Server (if needed)**

If using a custom server, ensure proper MIME types:

```javascript
// server.js
const { createServer } = require('http');
const { parse } = require('url');
const next = require('next');

const dev = process.env.NODE_ENV !== 'production';
const app = next({ dev });
const handle = app.getRequestHandler();

app.prepare().then(() => {
  createServer((req, res) => {
    const parsedUrl = parse(req.url, true);
    
    // Set proper MIME types
    if (parsedUrl.pathname?.endsWith('.css')) {
      res.setHeader('Content-Type', 'text/css; charset=utf-8');
    } else if (parsedUrl.pathname?.endsWith('.js')) {
      res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
    }
    
    handle(req, res, parsedUrl);
  }).listen(3000, (err) => {
    if (err) throw err;
    console.log('> Ready on http://localhost:3000');
  });
});
```

### **Solution 5: Check File Permissions**

```bash
# Ensure .next directory has correct permissions
chmod -R 755 .next
chmod -R 755 public
```

### **Solution 6: Clear Browser Cache**

1. Open DevTools (F12)
2. Right-click refresh button → "Empty Cache and Hard Reload"
3. Or use Incognito/Private mode

---

## 🔧 **Quick Fix Checklist**

- [ ] Stop Next.js server
- [ ] Delete `.next` directory
- [ ] Run `npm install` or `yarn install`
- [ ] Run `npm run build` (if production)
- [ ] Run `npm run dev` (if development)
- [ ] Clear browser cache
- [ ] Check browser console for new errors
- [ ] Verify `.next/static` directory exists
- [ ] Check CORS headers on API server

---

## 🎯 **For Videos Not Appearing**

After fixing MIME types, check:

1. **Firebase Configuration**
   - Ensure Firebase is initialized correctly
   - Check Firestore rules allow read access
   - Verify video URLs are accessible

2. **Video Service**
   - Check browser console for video loading errors
   - Verify video URLs in Firestore are correct
   - Check network tab for failed requests

3. **CORS for Video URLs**
   - If videos are hosted on different domain, ensure CORS is configured
   - Check Firebase Storage CORS settings

---

## 📝 **Next Steps**

1. **Identify your setup**:
   - Are you using `next dev` or a custom server?
   - Is this production or development?
   - Where is your website code located?

2. **Apply appropriate solution** from above

3. **Test**:
   - Check browser console (F12)
   - Verify static files load with correct MIME types
   - Test video loading

---

## 🆘 **If Still Not Working**

Share:
1. Your `next.config.js` file
2. Your server setup (custom server? nginx? etc.)
3. Full browser console errors
4. Network tab showing failed requests

This will help diagnose the specific issue.

