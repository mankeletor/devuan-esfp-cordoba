mkdir -p /etc/X11/Xsession.d
cat > /etc/X11/Xsession.d/99cd-home << 'INNER_EOF'
# Fix for working directory being / instead of $HOME
if [ "$PWD" = "/" ] && [ -n "$HOME" ] && [ -d "$HOME" ]; then
    cd "$HOME"
fi
INNER_EOF
