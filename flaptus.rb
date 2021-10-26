ROOT_PATH = File.expand_path(".", __dir__)

require "gosu"
require "yaml"

require_relative "flaptus/pipe.rb"
require_relative "flaptus/floor.rb"
require_relative "flaptus/player.rb"
require_relative "flaptus/buttons.rb"
require_relative "flaptus/background.rb"


module ZOrder
	BACKGROUND, PIPES, FLOOR, PLAYER, UI = *0...5
end


class Game < Gosu::Window
	def initialize
		super Background::IMAGE.width, Background::IMAGE.height
		self.caption = "Jumpy Cactus"

		@background_music = Gosu::Song.new("#{ROOT_PATH}/assets/audio/WHEN_THE_CAC_IS_TUS.mp3")
		@background_music.volume = 0.75
		@background_music.play(true)

		@heading = Gosu::Font.new(50, name: "#{ROOT_PATH}/assets/fonts/VarelaRound-Regular.ttf")
		@paragraph = Gosu::Font.new(20, name: "#{ROOT_PATH}/assets/fonts/VarelaRound-Regular.ttf")
		@score_text = Gosu::Font.new(35, name: "#{ROOT_PATH}/assets/fonts/VarelaRound-Regular.ttf")


		@fullscreen_button = FullScreenButton.new
		@fullscreen_button.warp(Background::IMAGE.width - @fullscreen_button.width - 20, 20)
		@buttons = [
			@fullscreen_button
		]

		@floor = Floor.new
		@floor.warp(0, Background::IMAGE.height - @floor.image.height)

		@player = Player.new
		@player.reset

		@pipes = []
		@next_pipe = 0

		@home_screen = true
		@playing = false
		@key_released = true
		@freeze_floor = false
		@start_spin = false
		@continue_spin = false

		@gap_height = 150

		@speed = 1.0
	end

	def update
		if @home_screen
			@buttons.each { |button| button.check_hover(self.mouse_x, self.mouse_y) }

			if (Gosu.button_down?(Gosu::KB_SPACE) || Gosu.button_down?(Gosu::MS_LEFT)) && @key_released
				@key_released = false

				if @fullscreen_button.hover?
					@fullscreen_button.click
					self.fullscreen = !self.fullscreen?
				else
					@home_screen = false
					@playing = true
					@player.reset
					@pipes = []
				end
			elsif !(Gosu.button_down?(Gosu::KB_SPACE) || Gosu.button_down?(Gosu::MS_LEFT))
				@key_released = true
			end
		elsif @playing
			pipes_within_x = @pipes[0..1].select { |pair| pair[0].within_x?(@player) }
			not_within_gap = pipes_within_x.length == 1 ? !pipes_within_x[0][0].within_gap_y?(@player, @gap_height) : false

			if @floor.y - @player.y <= 50 || not_within_gap
				@start_spin = true
				@freeze_floor = true
				@playing = false
				return
			elsif (Gosu.button_down?(Gosu::KB_SPACE) || Gosu.button_down?(Gosu::MS_LEFT)) && @key_released
				@key_released = false
				@player.jump
			elsif !(Gosu.button_down?(Gosu::KB_SPACE) || Gosu.button_down?(Gosu::MS_LEFT))
				@key_released = true
			end
			@player.move

			if @pipes.length == 0 || @pipes[-1][0].x < Background::IMAGE.width / 2
				new_down_pipe = Pipe.new("down")
				new_up_pipe = Pipe.new("up")
				gap_center = rand(100..(Background::IMAGE.height - 150))

				new_down_pipe.warp(Background::IMAGE.width, gap_center - new_down_pipe.image.height - @gap_height/2)
				new_up_pipe.warp(Background::IMAGE.width, gap_center + @gap_height/2)

				@pipes << [new_down_pipe, new_up_pipe]
			end

			@pipes.reject! { |pair| pair[0].x + pair[0].width <= 0 }
			@pipes.each do |pair|
				pair[0].move(@speed)
				pair[1].move(@speed)
				if @player.x > pair[0].x + pair[0].width && !pair[0].passed_player
					pair[0].passed_player = pair[1].passed_player = true
					@player.increase_score
				end
			end
		end
	end

	def draw
		Background.draw(0, 0, ZOrder::BACKGROUND)

		if @home_screen
			@buttons.each { |button| button.draw }

			@score_text.draw_text("High score: #{@player.high_score}", 15, 15, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
			@score_text.draw_text("Average score: #{@player.average_score.round(2)}", 15, 50, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
			@heading.draw_text("FLAPTUS", Background::IMAGE.width / 2 - 105, Background::IMAGE.height / 2 - 25, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
			@paragraph.draw_text("Click or press spacebar to play", Background::IMAGE.width / 2 - 132.5, Background::IMAGE.height / 2 + 25, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
		end


		@floor.move(@speed) unless @freeze_floor
		@floor.draw

		if @playing || @start_spin || @continue_spin
			@pipes.each do |pair|
				pair[0].draw
				pair[1].draw
			end

			@score_text.draw_text("High score:	#{@player.high_score}", 15, 15, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
			@score_text.draw_text("Current score: #{@player.score}", 15, 50, ZOrder::UI, 1.0, 1.0, Gosu::Color::GREEN)
		end

		if @start_spin
			@background_music.pause
			Thread.new do
				sleep 1.75
				@background_music.play(true)
			end

			@player.start_death_spin
			@start_spin = false
			@continue_spin = true
		elsif @continue_spin
			@player.death_spin
			if Background::IMAGE.height - @player.y <= 0
				@continue_spin = false
				@home_screen = true
				@freeze_floor = false
				@speed = 1.0
			end
		elsif @playing
			@player.draw
			@speed += 0.00075
		end
	end

	def button_down(id)
		if id == Gosu::KB_ESCAPE
			close
		else
			super
		end
	end
end

Game.new.show