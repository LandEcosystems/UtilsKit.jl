import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import path from 'path'

// https://vitepress.dev/reference/site-config

// Navigation menu items
const navItems = [
  { text: 'Home', link: '/' },
  { 
    text: 'API', 
    items: [
      { text: 'Overview', link: '/api' },
      { text: 'OmniTools (flat)', link: '/api/OmniTools' },
      { text: 'ForArray', link: '/api/ForArray' },
      { text: 'ForCollections', link: '/api/ForCollections' },
      { text: 'ForDisplay', link: '/api/ForDisplay' },
      { text: 'ForDocStrings', link: '/api/ForDocStrings' },
      { text: 'ForLongTuples', link: '/api/ForLongTuples' },
      { text: 'ForMethods', link: '/api/ForMethods' },
      { text: 'ForNumber', link: '/api/ForNumber' },
      { text: 'ForPkg', link: '/api/ForPkg' },
      { text: 'ForString', link: '/api/ForString' },
    ]
  },
]

// Sidebar configuration
const sidebarItems = [
  {
    text: 'Getting Started',
    items: [
      { text: 'Home', link: '/' },
    ]
  },
  {
    text: 'Documentation',
    collapsed: false,
    items: [
      { text: 'API Overview', link: '/api' },
      { text: 'OmniTools (flat)', link: '/api/OmniTools' },
      { text: 'ForArray', link: '/api/ForArray' },
      { text: 'ForCollections', link: '/api/ForCollections' },
      { text: 'ForDisplay', link: '/api/ForDisplay' },
      { text: 'ForDocStrings', link: '/api/ForDocStrings' },
      { text: 'ForLongTuples', link: '/api/ForLongTuples' },
      { text: 'ForMethods', link: '/api/ForMethods' },
      { text: 'ForNumber', link: '/api/ForNumber' },
      { text: 'ForPkg', link: '/api/ForPkg' },
      { text: 'ForString', link: '/api/ForString' },
    ]
  },
]

const sidebar = {
  '/': sidebarItems,
  '/api': sidebarItems,
  '/api/': sidebarItems,
}

export default defineConfig({
  base: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
  title: "OmniTools.jl",
  description: "A Julia package providing foundational utilities for arrays, collections, display formatting, and type introspection",
  lastUpdated: true,
  cleanUrls: false,
  ignoreDeadLinks: true,
  outDir: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
  
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
  ],
  
  vite: {
    define: {
      __DEPLOY_ABSPATH__: JSON.stringify('REPLACE_ME_DOCUMENTER_VITEPRESS_DEPLOY_ABSPATH'),
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '../components')
      }
    },
    build: {
      assetsInlineLimit: 0,
    },
    optimizeDeps: {
      exclude: [ 
        '@nolebase/vitepress-plugin-enhanced-readabilities/client',
        'vitepress',
        '@nolebase/ui',
      ], 
    }, 
    ssr: { 
      noExternal: [ 
        '@nolebase/vitepress-plugin-enhanced-readabilities',
        '@nolebase/ui',
      ], 
    },
  },

  markdown: {
    config(md) {
      md.use(tabsMarkdownPlugin)
    },
    theme: {
      light: "github-light",
      dark: "github-dark"
    }
  },

  themeConfig: {
    outline: 'deep',
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },

    nav: navItems,
    sidebar: sidebar,
    socialLinks: [
      {
        icon: "github",
        link: 'https://github.com/LandEcosystems/OmniTools.jl',
        ariaLabel: 'OmniTools.jl repository'
      },
    ],
    footer: {
      message: 'OmniTools.jl - Foundational utilities for Julia development',
      copyright: '© Copyright 2025 <strong>OmniTools.jl Contributors</strong>'
    }
  }
})
