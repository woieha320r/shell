"显示行号
set number

"TAB=4
set tabstop=4

"黑色背景
set background=dark

"编码设置
set encoding=utf-8

"启用256色
set t_Co=256

"当前行下划线
set cursorline

"垂直滚动最小边距
set scrolloff=8

"水平滚动最小边距
set sidescrolloff=8

"状态栏（不显示：0，多窗口显示：1，显示：2）
"set laststatus=2

"状态栏显示当前坐标
"set ruler

"缩进
"set shiftwidth=4
"set expandtab
"set smarttab
"set softtabstop=4
"set smartindent

"文件自动检测外部更改
"set autoread

"c文件自动缩进
"set cindent

"自动对齐
"set autoindent

"共享剪切板
"set clipboard=unnamed

"文件类型检测
"filetype indent on

"行宽
"set textwidth=80

"设置备份、交换、操作历史文件的保存位置，结尾的//表示生成的文件名带有绝对路径，路径中用%替换目录分隔符，以防止文件重名
"set dir=~/.vim/swp
"set backupdir=~/.vim/bak
"set undodir=~/.vim/undo

"保留撤销历史
"set undofile

"创建备份文件
"set backup

"创建交换文件
"set swapfile



"语法高亮
syntax on
syntax enable

"开启monokai配色，monokai.vim需置于~/.vim/colors/下
colorscheme monokai
