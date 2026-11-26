export NVM_DIR="$HOME/.nvm"
[[ ! -L $NVM_DIR && ( ! -e $NVM_DIR || ( -d $NVM_DIR && -O $NVM_DIR ) ) &&
   ! -L $NVM_DIR/nvm.sh && ! -e $NVM_DIR/nvm.sh.zwc && ! -L $NVM_DIR/nvm.sh.zwc ]] || return 1
if [[ -e $NVM_DIR/nvm.sh ]]; then
  [[ -f $NVM_DIR/nvm.sh && -O $NVM_DIR/nvm.sh && -r $NVM_DIR/nvm.sh ]] || return 1
  source "$NVM_DIR/nvm.sh"
fi
