#!/usr/bin/env bash
set -e

echo "🔨 Building Flutter Web Admin Panel..."
"/Users/marufahmed/Fontys Group Project/flutter/bin/flutter" build web --release

echo "📦 Copying web bundle to public/ for Vercel deployment..."
rm -rf public
mkdir -p public
cp -R build/web/* public/

echo "✅ Web bundle updated in public/! Commit and push to GitHub to trigger Vercel deployment."
