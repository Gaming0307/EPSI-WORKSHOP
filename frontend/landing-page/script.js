const wikiButton = document.getElementById("wiki")
const poxButton = document.getElementById("pox")
const forumButton = document.getElementById("forum")


wikiButton.addEventListener('click', () => {
    window.location.href = 'http://wiki.batman.com';
    console.log("redirection vers le wiki ! ")

});
poxButton.addEventListener('click', ()=>{

    window.location.href = 'http://mp.batman.com';
    console.log("redirection vers la messagerie hors ligne ! ")
})
forumButton.addEventListener('click', ()=>{

    window.location.href = 'http://forum.batman.com';
    console.log("redirection vers le forum ")
})
