class Star {
  constructor(canvas, startX, startY, color = '#ffffff') {
    this.canvas = canvas
    this.ctx = canvas.getContext('2d')
    this.x = startX
    this.y = startY
    this.size = Math.random() * 1 + 0.5
    this.speed = (Math.random() * 3 + 2) * 0.2
    this.tailLength = 20
    this.angle = Math.PI / 4
    this.opacity = Math.random() * 0.5 + 0.5
    this.color = color
  }

  update() {
    this.x += Math.cos(this.angle) * this.speed
    this.y += Math.sin(this.angle) * this.speed
  }

  draw() {
    const gradient = this.ctx.createLinearGradient(
      this.x, 
      this.y, 
      this.x - this.tailLength * Math.cos(this.angle),
      this.y - this.tailLength * Math.sin(this.angle)
    )
    
    gradient.addColorStop(0, this.color.replace('rgb', 'rgba').replace(')', `, ${this.opacity})`))
    gradient.addColorStop(1, this.color.replace('rgb', 'rgba').replace(')', ', 0)'))

    this.ctx.beginPath()
    this.ctx.moveTo(this.x, this.y)
    this.ctx.lineTo(
      this.x - this.tailLength * Math.cos(this.angle),
      this.y - this.tailLength * Math.sin(this.angle)
    )
    this.ctx.strokeStyle = gradient
    this.ctx.lineWidth = this.size
    this.ctx.stroke()
    
    // Draw the star point
    this.ctx.beginPath()
    this.ctx.arc(this.x, this.y, this.size/2, 0, Math.PI * 2)
    this.ctx.fillStyle = this.color.replace('rgb', 'rgba').replace(')', `, ${this.opacity})`)
    this.ctx.fill()
  }

  isOffScreen() {
    return (
      this.x > this.canvas.width + this.tailLength || 
      this.y > this.canvas.height + this.tailLength
    )
  }
}

export default {
  mounted() {
    const canvas = document.createElement('canvas')
    const container = this.el
    const interactionLayer = document.getElementById('interaction-layer')
    
    // Make canvas fill the entire space
    canvas.style.position = 'absolute'
    canvas.style.top = '0'
    canvas.style.left = '0'
    canvas.style.width = '100%'
    canvas.style.height = '100%'
    canvas.style.background = 'rgb(17 24 39)' // bg-gray-900
    container.appendChild(canvas)

    // Set actual canvas dimensions
    const resize = () => {
      const rect = canvas.getBoundingClientRect()
      canvas.width = rect.width
      canvas.height = rect.height
    }
    resize()
    window.addEventListener('resize', resize)

    const ctx = canvas.getContext('2d')
    const stars = []
    const maxStars = 20
    let lastMouseStarTime = 0
    let currentHue = 0

    // Function to get current rainbow color
    const getRainbowColor = () => {
      return `rgb(${getRainbowRGB(currentHue).join(',')})`
    }

    // Convert hue to RGB values
    const getRainbowRGB = (h) => {
      const f = (n, k = (n + h / 60) % 6) => Math.round(255 * (1 - Math.max(Math.min(k, 4 - k, 1), 0)))
      return [f(5), f(3), f(1)]
    }

    // Track mouse position and create stars
    const handleMouseMove = (e) => {
      const now = Date.now()
      if (now - lastMouseStarTime > 50) {
        const rect = canvas.getBoundingClientRect()
        const x = e.clientX - rect.left
        const y = e.clientY - rect.top
        
        stars.push(new Star(canvas, x, y, getRainbowColor()))
        lastMouseStarTime = now
      }
    }
    
    // Add mouse listener to the interaction layer instead of the canvas
    interactionLayer.addEventListener('mousemove', handleMouseMove)

    // Function to create a new background star
    const createBackgroundStar = () => {
      // Randomly choose between top and left side
      const startFromTop = Math.random() > 0.5
      let startX, startY

      if (startFromTop) {
        startX = Math.random() * canvas.width
        startY = -20
      } else {
        startX = -20
        startY = Math.random() * canvas.height * 0.8
      }

      return new Star(canvas, startX, startY)
    }

    // Initialize background stars
    for (let i = 0; i < maxStars; i++) {
      stars.push(createBackgroundStar())
    }

    // Animation loop
    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      // Update rainbow color (complete cycle every second)
      currentHue = (currentHue + 360/60) % 360 // 60 fps → 360° per second

      // Update and draw stars
      for (let i = stars.length - 1; i >= 0; i--) {
        stars[i].update()
        stars[i].draw()

        if (stars[i].isOffScreen()) {
          if (i < maxStars) {
            // Replace background stars
            stars[i] = createBackgroundStar()
          } else {
            // Remove mouse-created stars
            stars.splice(i, 1)
          }
        }
      }

      this.animationFrame = requestAnimationFrame(animate)
    }

    animate()

    // Update cleanup
    this.cleanup = () => {
      window.removeEventListener('resize', resize)
      interactionLayer.removeEventListener('mousemove', handleMouseMove)
      cancelAnimationFrame(this.animationFrame)
    }
  },

  destroyed() {
    if (this.cleanup) {
      this.cleanup()
    }
  }
}